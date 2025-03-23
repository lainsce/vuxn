public class Deck {
    private Card[] cards;
    private int current_index;
    
    /**
     * Create a new deck with 52 regular cards and 2 jokers
     */
    public Deck() {
        this.cards = new Card[54]; // 52 cards + 2 jokers
        this.reset();
    }
    
    /**
     * Reset the deck to its initial state with all cards
     */
    public void reset() {
        int index = 0;
        
        // Create regular cards
        for (int suit = 0; suit < 4; suit++) {
            for (int value = 1; value <= 13; value++) {
                this.cards[index] = new Card((CardSuit)suit, value);
                index++;
            }
        }
        
        // Add jokers - Red and Black Donsol
        this.cards[52] = new Card(CardSuit.JOKER, 1); // Red Donsol
        this.cards[53] = new Card(CardSuit.JOKER, 2); // Black Donsol
        
        this.current_index = 0;
        this.shuffle();
    }
    
    /**
     * Shuffle the entire deck using Fisher-Yates algorithm
     */
    public void shuffle() {
        // Fisher-Yates shuffle algorithm
        for (int i = this.cards.length - 1; i > 0; i--) {
            int j = Random.int_range(0, i + 1);
            Card temp = this.cards[i];
            this.cards[i] = this.cards[j];
            this.cards[j] = temp;
        }
    }
    
    /**
     * Draw the next card from the deck
     * @return The next card, or null if no cards remain
     */
    public Card? draw_card() {
        if (this.current_index >= this.cards.length) {
            return null;
        }
        
        return this.cards[this.current_index++];
    }
    
    /**
     * Add cards back to the deck and shuffle the remaining cards
     * @param cards_to_add Array of cards to add back
     */
    public void add_cards(Card[] cards_to_add) {
        // No cards to add
        if (cards_to_add.length == 0) {
            return;
        }
        
        // Add cards back to the deck
        foreach (var card in cards_to_add) {
            // Reset card state
            card.folded = false;
            
            // We can only add cards if we have room (if we've drawn any)
            if (current_index > 0) {
                current_index--;
                cards[current_index] = card;
            }
        }
        
        // Shuffle only the remaining cards
        shuffle_remaining();
    }
    
    /**
     * Shuffle only the remaining (undrawn) cards in the deck
     */
    private void shuffle_remaining() {
        // Use Fisher-Yates but only on undrawn portion
        for (int i = cards.length - 1; i >= current_index; i--) {
            int j = Random.int_range(current_index, i + 1);
            Card temp = cards[i];
            cards[i] = cards[j];
            cards[j] = temp;
        }
    }
    
    /**
     * Get the number of cards remaining in the deck
     * @return Number of remaining cards
     */
    public int remaining_cards() {
        return this.cards.length - this.current_index;
    }
    
    /**
     * Get the current state of the deck (remaining cards)
     * @return Array of remaining cards
     */
    public Card[] get_current_deck() {
        Card[] current_deck = new Card[cards.length - current_index];
        for (int i = 0; i < current_deck.length; i++) {
            current_deck[i] = cards[current_index + i];
        }
        return current_deck;
    }
}