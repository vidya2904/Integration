public class quoteImportJsonWrapper {
	public quoteImportJsonWrapper()
    {      

    }
    public Document document;
    public class Quote {
    	public String status;
    	public Client client;
    	public QuoteSetup quoteSetup;
        public producer producer;
        public String externalId;
        // public String producer;
        public generalInfo generalInfo;
    }
    public class QuoteSetup {
        public String segment;
        public Boolean multiOptions;
        public Boolean multiDivisions;
        public Boolean autoMapDivCls;
        public String autoCalcGroups;
        public Boolean experienceHistory;
		public Boolean noProducer; 
        public Boolean rateHistory;                 
        
    }
    public class producer {
        public String firstName;
        public String lastName;
        public String producerCode;
        public agency agency;
    }
    
    public class agency {
        public String agencyName ;
    }
    public class generalInfo {
        public String neededDate;
        public String receivedDate;
        public stakeholder stakeholder;
        public String effectiveDate;
    }
    public class stakeholder {
        public String underwritingTeam;
        public String underwritingTeam2;
        public String salesRep;
        public String financialAnalyst ;
        public String salesSupRep ;
    }
    
    
    public class clientBusinessInfo {
        public String collarMix;
        public questionAnswer questionAnswer;
    }
    public class questionAnswer {
        public String questionCode;
    }
    public class organization {
        public Boolean confidentialClient;
        public String situsState;
        public String situsZip;
    }
    public class Client {
        public String createdDate;        
        public String policyDate;
        public String status;
        public String fullName;
        public String industryCode;
        public String externalId;
        public clientBusinessInfo clientBusinessInfo; 
        public organization organization;
    }
    public class Document {
        public Quote quote;
    }
    public static quoteImportJsonWrapper parse(String json) {        
        return (quoteImportJsonWrapper) System.JSON.deserialize(json, quoteImportJsonWrapper.class);        
    }
}