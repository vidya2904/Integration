public class GIQXTokenManager {

    private static final String ENCODING_XML = 'application/x-www-form-urlencoded;charset=UTF-8';
    private static final String ENCODING_JSON = 'application/json';
	private static final String CMT_FIELD_SCOPE = 'Scope__c';
    private static final String GRANT_TYPE_PARAM = 'grant_type';
    private static final String CLIENT_ID_PARAM = 'client_id';
    private static final String SCOPE_PARAM = 'scope';
    private static final String GRANT_TYPE_CLIENT_CREDS = 'client_credentials';
    private static final String BODY_START = 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=';
    private static final String REFRESH_BODY_START = 'grant_type=refresh_token&refresh_token=';
    @TestVisible private static final String ACCESS_TOKEN_KEY = 'apigeeAccessToken';
    @TestVisible private static final String LEGACY_ACCESS_TOKEN_KEY = 'legacyApigeeAccessToken';
    private static final String LEGACY_GRS_ACCESS_TOKEN_KEY = 'legacyGRSApigeeAccessToken';
    @TestVisible private static final String CACHE_PARTITION = 'GIQXSessionPartition';
    private static final String TOKENS_API_KEY = 'GIQXTokensAPI';
    
    private static final String LEGACY_TOKENS_API_KEY = 'GIQXLegacyTokensAPI';
    @TestVisible private static final String GIQX_GENERATE_TOKEN_ENDPOINT_NAME = 'GIQX Generate Token';
    @TestVisible private static final String GIQX_LEGACY_GENERATE_TOKEN_ENDPOINT_NAME = 'GIQX Legacy Generate Token';
    @TestVisible private static final String GIQX_REFRESH_TOKEN_ENDPOINT_NAME = 'GIQX Refresh Token';
    @TestVisible private static final String GIQX_LEGACY_REFRESH_TOKEN_ENDPOINT_NAME = 'GIQX Legacy Refresh Token';
    @TestVisible private static final Integer REFRESH_TOKEN_BUFFER_TIME = 5;
    @TestVisible private static final Integer ACCESS_TOKEN_BUFFER_TIME = 5;
    private static final Integer CACHE_TIME_TO_LIVE_SECONDS = 7200;
    private static final String CONSUMER_KEY_KEY = 'consumerKey';
    private static final String AUTH_KEY_KEY = 'authKey';
    public Boolean isLegacy {get;set;}
    public String hostURL {get;set;}


    public GIQXTokenManager(Boolean isLegacy){
        this.isLegacy = isLegacy;
    }

    public Map<String,String> keyFromCommunityMetaData {
        get{
            CommunityConfig__mdt commDomain = CLCommunityHelper.getCommunityConfig();
            return new Map<String, String>{
                CONSUMER_KEY_KEY => commDomain.Consumer_Key__c,
                AUTH_KEY_KEY => commDomain.Authorization_Key__c
            };
        }
        set;
    }

    @TestVisible
    public Keys__c Key {
        get {
            if(Key == NULL) {
                String apiKey = TOKENS_API_KEY;
                if(isLegacy){
                    apiKey = LEGACY_TOKENS_API_KEY;
                }
                Map<String, Keys__c> settings = Keys__c.getAll();
                Keys__c authKey = settings.get(apiKey);
                Key = authKey;
            }
            return Key;
        }
        set;
    }

    

    public List<Endpoint__c> Endpoints {
        get {
            if(Endpoints == NULL) {
                Endpoints = getEndpoints();
            }
            return Endpoints;
        }
        set;
    }

    public static List<Endpoint__c> getEndpoints() {
        return [
            SELECT
                Name,
                Endpoint__c,
                Org__c
            FROM Endpoint__c
        ];
    }

    public static Boolean IsRunningInASandbox {
        get {
            if(IsRunningInASandbox == NULL) {
                IsRunningInASandbox = [
                    SELECT IsSandbox FROM Organization LIMIT 1
                ].IsSandbox;
            }
            return IsRunningInASandbox;
        }
        set;
    }

    private TokenResponse ExistingToken {
        get {
            try{
                if(ExistingToken == NULL) {
                    String key = ACCESS_TOKEN_KEY;
                    if(isLegacy)
                        key = LEGACY_ACCESS_TOKEN_KEY;
                    Cache.SessionPartition sessionPart = Cache.Session.getPartition(CACHE_PARTITION);
                    if (sessionPart.contains(key)) {
                        System.debug('Returning  access token from cache');
                        TokenResponse token = (TokenResponse)sessionPart.get(key);
                        if(token.refresh_token_expiry_datetime > Datetime.now().addMinutes(REFRESH_TOKEN_BUFFER_TIME))
                            ExistingToken = token;
                    }
                }
            }catch(Exception ee){
                System.debug('------Cache.Session Not Found----->');
            }    
            return ExistingToken;
        }
        set;
    }

    public String getAccessTokenUsingMetaData(){
        if(ExistingToken != NULL) {
            if(isExistingAccessTokenValid()) {
                return ExistingToken.access_token;
            }
            else {
                TokenResponse refreshToken = refreshExistingTokenUsingMetaData(ExistingToken.refresh_token);
                cacheAccessToken(refreshToken);
        		return refreshToken.access_token;
            }
        }
        else {
            System.debug('No existing token------>');
            TokenResponse newToken =  generateNewTokenFromMetaData();
            User usr = IMSCommunityHelper.getUserbyId(UserInfo.getUserId());
            //only cache token if user is account linked
            if(usr!=null && usr.Account_Link_Status__c == ClimsConstants.USER_ACCOUNT_LIKE_STATUS_LINKED) {
                cacheAccessToken(newToken);
            }
        	return newToken.access_token;
        }
    }

    public String getAccessToken() {
        if(ExistingToken != NULL) {
            System.debug('existing token found');
            if(isExistingAccessTokenValid()) {
                System.debug('existing token found & valid ');
                return ExistingToken.access_token;
            }
            else {
                System.debug('existing token expired- call refresh token');
                TokenResponse refreshToken = refreshExistingToken(ExistingToken.refresh_token);
                cacheAccessToken(refreshToken);
                System.debug('refresh token:'+refreshToken.refresh_token);
        		return refreshToken.access_token;
            }
        }
        else {
            System.debug('No existing token------>');
            TokenResponse newToken =  generateNewToken();
            User usr = IMSCommunityHelper.getUserbyId(UserInfo.getUserId());
            //only cache token if user is account linked
            if(usr!=null && usr.Account_Link_Status__c == ClimsConstants.USER_ACCOUNT_LIKE_STATUS_LINKED) {
                cacheAccessToken(newToken);
            }
        	return newToken.access_token;
        }
    }

    private Boolean isExistingAccessTokenValid() {
        return ExistingToken.access_token_expiry_datetime > Datetime.now().addMinutes(ACCESS_TOKEN_BUFFER_TIME);
    }

    private TokenResponse refreshExistingToken(String refreshToken) {

        System.debug('refreshToken');

        final HttpRequest req = new HttpRequest();


		final String body = getBody(true)+refreshToken;
        req.setEndpoint(getRefreshEndPoint());
        req.setHeader('Consumer-Key',key.Consumer__c);
        req.setHeader('Content-Type',ENCODING_XML);
        req.setHeader('Authorization', key.Authorization__c);
        req.setMethod('GET');
        req.setBody(body);

        final HTTPResponse res = new Http().send(req);

        System.debug('Token Response Status: ' + res.getStatus() + ' ' + res.getStatusCode());
        final Integer statusCode = res.getStatusCode();

        if ( statusCode == 200) {
            TokenResponse token =  deserializeToken(res.getBody());
            return token;

        } else if (statusCode == 401) {
            //in case refresh token is expired,get new access token
            return generateNewToken();
        }
        else  {
            return deserializeToken(res.getBody());
        }

    }

    private TokenResponse refreshExistingTokenUsingMetaData(String refreshToken) {

        final HttpRequest req = new HttpRequest();
        
		final String body = getBody(true)+refreshToken;
        req.setEndpoint(getRefreshEndPoint());
        req.setHeader('Consumer-Key',keyFromCommunityMetaData.get(CONSUMER_KEY_KEY));
        req.setHeader('Content-Type',ENCODING_XML);
        req.setHeader('Authorization', keyFromCommunityMetaData.get(AUTH_KEY_KEY));
        req.setMethod('GET');
        req.setBody(body);

        final HTTPResponse res = new Http().send(req);

        System.debug('Token Response Status: ' + res.getStatus() + ' ' + res.getStatusCode());
        final Integer statusCode = res.getStatusCode();

        if ( statusCode == 200) {
            TokenResponse token =  deserializeToken(res.getBody());
            return token;

        } else if (statusCode == 401) {
            //in case refresh token is expired,get new access token
            return generateNewTokenFromMetaData();
        }
        else  {
            return deserializeToken(res.getBody());
        }

    }

    private TokenResponse generateNewTokenFromMetaData(){
        final HttpRequest req = new HttpRequest();


        final String body = getBody(false);
        req.setEndpoint(getGenerateEndPoint());
        req.setHeader('Consumer-Key',keyFromCommunityMetaData.get(CONSUMER_KEY_KEY));
        req.setHeader('Content-Type',ENCODING_XML);
        req.setHeader('Authorization', keyFromCommunityMetaData.get(AUTH_KEY_KEY));
        req.setMethod('GET');
        req.setBody(body);

        final HTTPResponse res = new Http().send(req);

        System.debug('Token Response Status: ' + res.getStatus() + ' ' + res.getStatusCode());
        final Integer statusCode = res.getStatusCode();

        if ( statusCode == 200) {
            TokenResponse token =  deserializeToken(res.getBody());
            return token;

        } else  {
            return deserializeToken(res.getBody());
        }

    }

    private TokenResponse generateNewToken() {

        System.debug('in generate Token');

        final HttpRequest req = new HttpRequest();


        final String body = getBody(false);
        system.debug('body==='+body);
        system.debug('key==='+key);
        //req.setEndpoint('https://dev-api.canadalife.com/oauth2/v1/generate');//getGenerateEndPoint()
        req.setEndpoint('https://test-api.canadalife.com/oauth2/v1/generate');
        //req.setEndpoint('https://devp42new.canadalife.com/oauth2/v1/generate');
        //https://test-api.canadalife.com/tokens/v1/generate 
        req.setHeader('Consumer-Key','8QzTq0DET9nLlQmrfqARgGY4N8cGUM9d');
		req.setHeader('Consumer-Secret','XriYPXoyyYrQAUAl');
		req.setHeader('Authorization','Basic OFF6VHEwREVUOW5MbFFtcmZxQVJnR1k0TjhjR1VNOWQ6WHJpWVBYb3l5WXJRQVVBbA==');

        /*req.setHeader('Consumer-Key',key.Consumer__c);
        req.setHeader('Content-Type',ENCODING_XML);
        req.setHeader('Authorization', key.Authorization__c);*/
        req.setMethod('GET');
        req.setBody(body);
system.debug('req==='+body);
        final HTTPResponse res = new Http().send(req);

        System.debug('Token Response Status: ' + res.getStatus() + ' ' + res.getStatusCode());
        final Integer statusCode = res.getStatusCode();

        if ( statusCode == 200) {
            TokenResponse token =  deserializeToken(res.getBody());
            return token;

        } else  {
            return deserializeToken(res.getBody());
        }

    }


    //deserialise response and return token
    @testVisible
    private TokenResponse deserializeToken(String responseBody) {

        System.debug('token response:' +responseBody);

        // use default parsing for everything we can.
        TokenResponse parsedResponse = (TokenResponse) System.JSON.deserialize(responseBody, TokenResponse.class);
        if (!parsedResponse.isError()) {
            parsedResponse.access_token_expiry_datetime = String.isNotBlank(parsedResponse.issued_at) && String.isNotBlank(parsedResponse.expires_in) ?
            Datetime.newInstance(Long.valueOf(parsedResponse.issued_at)).addSeconds(Integer.valueOf(parsedResponse.expires_in)) : NULL;

            parsedResponse.refresh_token_expiry_datetime = String.isNotBlank(parsedResponse.issued_at) && String.isNotBlank(parsedResponse.refresh_token_expires_in) ?
            Datetime.newInstance(Long.valueOf(parsedResponse.issued_at)).addSeconds(Integer.valueOf(parsedResponse.refresh_token_expires_in)) : NULL;
            System.debug('refreshtoken expiry date time:'+parsedResponse.refresh_token_expiry_datetime);
        }
        System.debug('parsedResponse'+parsedResponse);
        return parsedResponse;

    }

    @testVisible
    private String encodeParameters(Map<String,String> config,boolean isRefresh) {

        Map<String,String> params = new Map<String,String>();
        if(isRefresh)
             params.put(GRANT_TYPE_PARAM,'refresh_token');
        else
        	params.put(GRANT_TYPE_PARAM,GRANT_TYPE_CLIENT_CREDS);
        final String scope = config.get(CMT_FIELD_SCOPE);
        if (!String.isEmpty(scope)) {
            params.put(SCOPE_PARAM,scope);
        }
        return encodeAsURL(params);
    }

    @testVisible
    private String getBody(boolean isRefresh) {
        if(isRefresh){
            return REFRESH_BODY_START;
        } else {
            CLGIQXGenerator giqxGen = new CLGIQXGenerator();
        	return BODY_START + giqxGen.generateGIQXToken();
        }

    }


    private String encodeAsURL(Map<String,String> params) {
        String output = '';
        for (String key : params.keySet()) {
            output += (String.isEmpty(output) ? '' : '&');
            output += key + '=' + params.get(key);
        }
        return output;
    }

    private void cacheAccessToken(TokenResponse token) {
        String key = ACCESS_TOKEN_KEY;
        if(isLegacy)
            key = LEGACY_ACCESS_TOKEN_KEY;
        try{
            Cache.Session.getPartition(CACHE_PARTITION).put(key, token, CACHE_TIME_TO_LIVE_SECONDS);
        }catch(Exception ee){
            System.debug('---Cache.Session.getPartition Not Found----->');
        }    
	}

	public Boolean clearAccessToken() {
        String key = ACCESS_TOKEN_KEY;
        if(isLegacy)
            key = LEGACY_ACCESS_TOKEN_KEY;
    	return Cache.Session.getPartition(CACHE_PARTITION).remove(key);
	}

    public String getGenerateEndpoint() {
        for(Endpoint__c endpoint : Endpoints) {
            if(isLegacy) {
                if(endpoint.Name == GIQX_LEGACY_GENERATE_TOKEN_ENDPOINT_NAME && IsRunningInASandbox && endpoint.Org__c == Request.QA_ORG_NAME) {
                	return endpoint.Endpoint__c;
            	} else if(endpoint.Name == GIQX_LEGACY_GENERATE_TOKEN_ENDPOINT_NAME && !IsRunningInASandbox && endpoint.Org__c == Request.PRODUCTION_ORG_NAME) {
                    return endpoint.Endpoint__c;
                }
            }
            else {
                if(endpoint.Name == GIQX_GENERATE_TOKEN_ENDPOINT_NAME && IsRunningInASandbox && endpoint.Org__c == Request.QA_ORG_NAME) {
                	return endpoint.Endpoint__c;
            	} else if(endpoint.Name == GIQX_GENERATE_TOKEN_ENDPOINT_NAME && !IsRunningInASandbox && endpoint.Org__c == Request.PRODUCTION_ORG_NAME) {
                    return endpoint.Endpoint__c;
                }
            }

        }
        return '';
    }

    public String getRefreshEndpoint() {
        for(Endpoint__c endpoint : Endpoints) {
           if(isLegacy) {
                if(endpoint.Name == GIQX_LEGACY_REFRESH_TOKEN_ENDPOINT_NAME && IsRunningInASandbox && endpoint.Org__c == Request.QA_ORG_NAME) {
                	return endpoint.Endpoint__c;
            	} else if(endpoint.Name == GIQX_LEGACY_REFRESH_TOKEN_ENDPOINT_NAME && !IsRunningInASandbox && endpoint.Org__c == Request.PRODUCTION_ORG_NAME) {
                	return endpoint.Endpoint__c;
            	}
            }
            else {
                if(endpoint.Name == GIQX_REFRESH_TOKEN_ENDPOINT_NAME && IsRunningInASandbox && endpoint.Org__c == Request.QA_ORG_NAME) {
                	return endpoint.Endpoint__c;
            	} else if(endpoint.Name == GIQX_REFRESH_TOKEN_ENDPOINT_NAME && !IsRunningInASandbox && endpoint.Org__c == Request.PRODUCTION_ORG_NAME) {
                	return endpoint.Endpoint__c;
            	}
            }

        }
        return '';
    }

    public String getConsumerKeyKey(){
        return CONSUMER_KEY_KEY;
    }

    public String getAuthKeyKey(){
        return AUTH_KEY_KEY;
    }

    public class TokenResponse {
        public String refresh_token_expires_in {get;set;}
        public String refresh_token_issued_at {get;set;}
        public String api_product_list {get;set;}
        public List<String> api_product_list_json {get;set;}
        public String organization_name {get;set;}
        public String developer_email {get;set;}
        public String token_type {get;set;}
        public String issued_at {get;set;}
        public String client_id {get;set;}
        public String access_token {get;set;}
        public Datetime access_token_expiry_datetime {get;set;}
        public String refresh_token {get;set;}
        public Datetime refresh_token_expiry_datetime {get;set;}
        public String application_name {get;set;}
        public String scope {get;set;}
        public String expires_in {get;set;}
        public String refresh_count {get;set;}
        public String status {get;set;}
        public String ErrorCode {get; set;}
        public String Error {get; set;}
        public Fault fault {get; set;}

        public Boolean isError() {
            return Error != null || fault != null;
        }

        public String getErrorMessage() {
            if (Error != null) {
                return ErrorCode;
            }

            if (fault != null) {
                return fault.faultString.replace('{0}',fault.detail.errorcode);
            }
            return null;
        }
    }

    public class Fault {
        public String faultstring {get;set;}
        public Detail detail {get;set;}
    }

    public class Detail {
        public String errorcode {get;set;}
    }

    public class TokenException extends Exception {

    }

}