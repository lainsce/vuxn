public class Room {
    public Card[] cards;
    
    public Room() {
        this.cards = {};
    }
    
    // Add card to room
    public void add_card(Card card) {
        Card[] new_cards = new Card[cards.length + 1];
        
        // Copy existing cards
        for (int i = 0; i < cards.length; i++)
            new_cards[i] = cards[i];
            
        // Add new card
        new_cards[cards.length] = card;
        cards = new_cards;
    }
    
    // Check if room is cleared
    public bool is_cleared() {
        foreach (var card in cards)
            if (!card.folded)
                return false;
        return true;
    }
    
    // Check if room has monsters
    public bool has_monsters() {
        foreach (var card in cards)
            if (!card.folded && card.is_monster())
                return true;
        return false;
    }
    
    // Get unfolded cards
    public Card[] get_unfolded_cards() {
        // Count unfolded cards
        int count = 0;
        foreach (var card in cards)
            if (!card.folded)
                count++;
                
        // Create result array
        Card[] result = new Card[count];
        int index = 0;
        
        foreach (var card in cards)
            if (!card.folded)
                result[index++] = card;
                
        return result;
    }
}