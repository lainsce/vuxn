public enum CardSuit {
    HEARTS,
    DIAMONDS,
    CLUBS,
    SPADES,
    JOKER
}

public class Card {
    public CardSuit suit;
    public int value;
    public bool folded;
    
    public Card(CardSuit suit, int value) {
        this.suit = suit;
        this.value = value;
        this.folded = false;
    }
    
    // Return if card is red (hearts/diamonds)
    public bool is_red() {
        return suit == CardSuit.HEARTS || suit == CardSuit.DIAMONDS;
    }
    
    // Return if card is a face card
    public bool is_face() {
        return value >= 11 || value == 1;
    }
    
    // Return if card is a monster
    public bool is_monster() {
        return suit == CardSuit.CLUBS || suit == CardSuit.SPADES || suit == CardSuit.JOKER;
    }
    
    // Return if card is a shield
    public bool is_shield() {
        return suit == CardSuit.DIAMONDS;
    }
    
    // Return if card is a potion
    public bool is_potion() {
        return suit == CardSuit.HEARTS;
    }
    
    // Get card text representation
    public string value_text() {
        if (suit == CardSuit.JOKER)
            return "D";
            
        switch (value) {
            case 1: return "A";
            case 10: return "X";
            case 11: return "J";
            case 12: return "Q";
            case 13: return "K";
            default: return value.to_string();
        }
    }
    
    // Get effective game value
    public int effect_value() {
        if (suit == CardSuit.JOKER)
            return 21;
            
        if (is_potion() || is_shield()) {
            // Potions and shields: J,Q,K,A are all 11
            if (value >= 11 || value == 1)
                return 11;
        } else {
            // Monsters: J=11, Q=13, K=15, A=17
            if (value == 1) return 17;      // Ace
            if (value == 11) return 11;     // Jack
            if (value == 12) return 13;     // Queen
            if (value == 13) return 15;     // King
        }
        
        return value;
    }
    
    // Get potion name including effect value
    public string potion_name() {
        if (!is_potion())
            return "";
        
        string base_name;
        
        // Face cards (J, Q, K, A)
        if (is_face())
            base_name = "Red Mage";
        // Value-based names
        else if (value >= 1 && value <= 5)
            base_name = "Potion";
        else // values 6-10
            base_name = "Super Potion";
        
        return "%s %d".printf(base_name, effect_value());
    }

    // Get shield name including effect value
    public string shield_name() {
        if (!is_shield())
            return "";
        
        string base_name;
        
        // Face cards (J, Q, K, A)
        if (is_face())
            base_name = "White Mage";
        // Value-based names
        else if (value >= 1 && value <= 3)
            base_name = "Buckler";
        else if (value >= 4 && value <= 6)
            base_name = "Kite";
        else // values 7-10
            base_name = "Tower";
        
        return "%s %d".printf(base_name, effect_value());
    }
    
    // Get monster name
    public string monster_name() {
        if (!is_monster())
            return "";
        
        if (suit == CardSuit.JOKER) {
            // Red or Black Donsol based on value
            if (value == 1)
                return "Red Donsol";
            else
                return "Black Donsol";
        }
        
        // Ordered monster names by value
        string[] names = {
            "Rat", "Slime", "Tunneler", "Fiend", "Drake", "Specter", 
            "Ghost", "Ogre", "Witch", "Demon", "Medusa", 
            "Consort", "Regnant", "Empress", "Mage"
        };
        
        // Use value - 1 directly for indexing (already ordered)
        int index = (value - 1) % names.length;
        return "%s %d".printf(names[index], effect_value());
    }
}