public class GIQXCreateQuote {
	@InvocableMethod(label='Create Quote' description='Create Quote')
    public static List<CreateQuoteResult> createQuote(List<CreateQuoteResult> request){
        
        //parse inputs and variables
         List<String> mess = request.get(0).erroMessages;
        
        //parse outputs
        CreateQuoteResult result = new CreateQuoteResult();        
        List<CreateQuoteResult> resultList = new List<CreateQuoteResult>();
        resultList.add(result);
        return resultList;
    }
    
    
    public class CreateQuoteRequest{
        @InvocableVariable
        public String quote;
    }
    
    public class CreateQuoteResult{        
        
        @InvocableVariable
        public List<String> erroMessages;
    }
}