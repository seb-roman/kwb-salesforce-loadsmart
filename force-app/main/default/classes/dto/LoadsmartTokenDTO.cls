/**
 * DTO for Loadsmart OAuth 2.0 Token Response
 * 
 * Handles deserialization from:
 * POST /auth/token with grant_type=client_credentials
 * 
 * Provides type-safe access to token data
 */
public class LoadsmartTokenDTO {
    
    @AuraEnabled
    public String access_token { get; set; }
    
    @AuraEnabled
    public String token_type { get; set; }
    
    @AuraEnabled
    public Integer expires_in { get; set; }
    
    @AuraEnabled
    public String scope { get; set; }
    
    /**
     * Deserialize from JSON response body
     */
    public static LoadsmartTokenDTO parse(String jsonBody) {
        return (LoadsmartTokenDTO) JSON.deserialize(jsonBody, LoadsmartTokenDTO.class);
    }
    
    /**
     * Check if token is expired (with 60-second buffer)
     */
    public Boolean isExpired(DateTime issuedAt) {
        if (issuedAt == null || expires_in == null) {
            return true;
        }
        DateTime expirationTime = issuedAt.addSeconds(expires_in - 60);
        return DateTime.now() >= expirationTime;
    }
}
