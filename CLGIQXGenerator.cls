
**********************************************************************************************/
public class CLGIQXGenerator {

     //@TestVisible private static final String ISSUER = '6Cel800D4c0000008aRL8884c000000044x6mVmSaGke9nLuM0QLnPKy8sffN3ZXfXaeTsJuILLNii1KaH1ZToAt4g0LHTQlcsG77fGkwew';//'https://fit-lifeco.cs148.force.com/identity"';
    @TestVisible private static final String ISSUER = 'https://devims1-lifeco.cs99.force.com/identity' ;
    @TestVisible private static final String HOSTNAME = 'https://test-api.canadalife.com';
    @TestVisible private static final Integer TOKEN_VALIDITY_DURATION_SECONDS = 300;
    @TestVisible private static final String USERID_CLAIMS_KEY = 'userId';
    @TestVisible private static final String ROLES_CLAIMS_KEY = 'roles';
    private static final String DEFAULT_CERTIFICATE_NAME = 'certificate_identity_provider_london_life';

    @TestVisible
    private String CertificateName {
        get {
            if(CertificateName == NULL) {
                Map<String, JWT_Certificates__c> settings = JWT_Certificates__c.getAll();
                JWT_Certificates__c setting = settings.get('GIQXAuthentication');
                return setting != NULL ? setting.Certificate_Name__c : DEFAULT_CERTIFICATE_NAME;
            }
            return DEFAULT_CERTIFICATE_NAME;
        }
        set;
    }
    

    private String Subject {
        get {
            return UserInfo.getOrganizationId() + '@' + UserInfo.getUserName();
        }
        set;
    }

    public Auth.JWT JWTToken {get; private set;}

    @TestVisible
    private User CurrentUser {
        get {
            if(CurrentUser == NULL) {
                CurrentUser = [
                    SELECT
                        	Data_Contact_Eid__c,
                    		Id,
							Username,
							Email,
                    		GCCS_Agent_Role__c,
                            Federation_Id__c,	
                    		ProfileId
                    FROM User
                    WHERE Id = :UserInfo.getUserId()
                ];
            }
            return CurrentUser;
        }
        set;
    }

    // purpose: generate a JWT token
    public String generateGIQXToken() {
		
        Auth.JWT jwt = new Auth.JWT();
        
        jwt.setSub(Subject);
        jwt.setIss(ISSUER);
        jwt.setAud(HOSTNAME); 
        
        jwt.setAdditionalClaims(getClaims());
        jwt.setValidityLength(TOKEN_VALIDITY_DURATION_SECONDS);

        Auth.JWS jws = new Auth.JWS(jwt, 'certificate_identity_provider_london_life');

        String token = jws.getCompactSerialization();
        JWTToken = jwt;
        system.debug('Token======='+ token);
        return token;
    }

    // purpose: get additional claims to include in the JWT token
    private Map<String, Object> getClaims() {
        String role;
        if(CLVlocityCommunityHelper.isICUser()){
            CommunityConfig__mdt commDomain = CLCommunityHelper.getCommunityConfig();
            role = commDomain.API_Connectivity_Role__c;
        }

        Map<String, Object> jwtattributes = new Map<String, Object>(); 
           jwtattributes.put('userId', UserInfo.getUserId());
           jwtattributes.put('username', CurrentUser.Username);
           jwtattributes.put('email' , CurrentUser.Email);
           //jwtattributes.put('identityContactId' , String.isBlank(CurrentUser.ContactId)?'':CurrentUser.ContactId);
           /*if(!String.isBlank(CurrentUser.Data_Contact_Eid__c))
           {
                jwtattributes.put('dataFedId',CurrentUser.Federation_Id__c);
                //jwtattributes.put('digitalId','certificate_identity_provider_london_life');
           }*/
           jwtattributes.put('digitalId','certificate_identity_provider_london_life');
           /* if(!String.isBlank(role)){
                String [] roles = new String[]{role};
                jwtattributes.put('roles',roles);   
           } */
        return jwtattributes;
    }
}
