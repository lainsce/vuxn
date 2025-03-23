public enum DonsolDifficulty {
    EASY,
    NORMAL,
    HARD
}

public class DonsolGame {
    public Deck deck;
    public Player player;
    public Room current_room;
    public bool can_escape;
    public string status_message;
    public string current_monster_name;
    public DonsolDifficulty difficulty;
    public bool has_escaped_previously;
    
    public DonsolGame() {
        this.deck = new Deck();
        this.player = new Player();
        this.current_room = new Room();
        this.can_escape = true;
        this.status_message = "";
        this.current_monster_name = "";
        this.difficulty = DonsolDifficulty.NORMAL;
        this.has_escaped_previously = false;
    }
    
    // Start new game
    public void new_game(DonsolDifficulty difficulty = DonsolDifficulty.NORMAL) {
        deck.reset();
        player.reset();
        this.difficulty = difficulty;
        this.has_escaped_previously = false;
        update_can_escape();
        status_message = "Select a card to begin.";
        current_monster_name = "";
        draw_room();
    }
    
    // Update can_escape based on difficulty
    private void update_can_escape() {
        switch (difficulty) {
            case DonsolDifficulty.EASY:
                // Can escape when all monsters are dealt with OR not escaped previously
                can_escape = !has_escaped_previously || !current_room.has_monsters();
                break;
            case DonsolDifficulty.NORMAL:
                // Can escape only when not escaped previously
                can_escape = !has_escaped_previously;
                break;
            case DonsolDifficulty.HARD:
                // Can escape only when all monsters are dealt with
                can_escape = !current_room.has_monsters();
                break;
        }
    }
    
    // Draw a new room
    public void draw_room() {
        current_room = new Room();
        
        // Draw up to 4 cards
        for (int i = 0; i < 4; i++) {
            Card? card = deck.draw_card();
            if (card != null)
                current_room.add_card(card);
            else
                break;
        }
        
        // Reset potion sickness for new room
        player.potion_sickness = false;
        current_monster_name = "";
        
        // Update can_escape based on difficulty
        update_can_escape();
    }
    
    // Take card at index
    public void take_card(int index) {
        if (index >= current_room.cards.length || current_room.cards[index].folded)
            return;
        
        Card card = current_room.cards[index];
        card.folded = true;
        
        // Handle different card types
        if (card.is_potion())
            handle_potion(card);
        else if (card.is_shield())
            handle_shield(card);
        else if (card.is_monster())
            handle_monster(card);
        
        // Check if player is dead
        if (player.health <= 0) {
            player.health = 0;
            status_message = "You have died! Game Over.";
            return;
        }
        
        // Update can_escape based on difficulty
        update_can_escape();
        
        // Check if room is cleared
        if (current_room.is_cleared()) {
            draw_room();
            status_message = "You enter a new room.";
            has_escaped_previously = false;
        }
    }
    
    // Handle potion card
    private void handle_potion(Card card) {
        int heal = card.effect_value();
        
        if (player.potion_sickness) {
            status_message = "You are sick! Potion has no effect.";
        } else {
            int old_health = player.health;
            player.health = int.min(DonsolConstants.MAX_HEALTH, player.health + heal);
            status_message = "You drink a potion and gain %d HP.".printf(player.health - old_health);
            player.potion_sickness = true;
        }
    }
    
    // Handle shield card
    private void handle_shield(Card card) {
        int shield = card.effect_value();
        player.shield_value = shield;
        player.last_shield_value = shield;
        status_message = "You equip a shield with SP %d.".printf(shield);
    }
    
    // Handle monster card
    private void handle_monster(Card card) {
        int monster_value = card.effect_value();
        current_monster_name = card.monster_name();
        
        // Handle combat with or without shield
        if (player.shield_value > 0) {
            if (monster_value > player.last_shield_value) {
                // Shield breaks
                status_message = "Shield breaks! Took %d damage.".printf(monster_value);
                player.health -= monster_value;
                player.shield_value = 0;
            } else {
                // Shield absorbs damage
                int damage = int.max(0, monster_value - player.shield_value);
                status_message = "Shield absorbs damage. Took %d damage.".printf(damage);
                player.health -= damage;
                player.last_shield_value = monster_value;
            }
        } else {
            // No shield, take full damage
            status_message = "Took %d damage from the monster.".printf(monster_value);
            player.health -= monster_value;
        }
        
        // Gain XP for defeating the monster
        player.xp += monster_value;
    }
    
    // Escape from current room
    public void escape_room() {
        if (!can_escape) {
            status_message = "You cannot escape!";
            return;
        }
        
        if (!current_room.has_monsters()) {
            status_message = "There are no monsters to run from!";
            return;
        }
        
        // Get unfolded cards and add them back to the deck
        Card[] unfolded = current_room.get_unfolded_cards();
        deck.add_cards(unfolded);
        
        // Mark that player has escaped this room
        has_escaped_previously = true;
        
        // Create a new room
        draw_room();
        status_message = "You escape from the room.";
    }
}