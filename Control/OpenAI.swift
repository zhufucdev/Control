import OpenAI

class OpenAIService {
    let client: OpenAI
    static let shared: OpenAIService
    
    init(client: OpenAI) {
        self.client = client
    }
    
    convenience init(<#parameters#>) {
        <#statements#>
    }
}
