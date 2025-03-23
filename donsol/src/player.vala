public class Player {
    public int health;
    public int shield_value;
    public bool potion_sickness;
    public int last_shield_value;
    public int xp;  // Added XP tracking
    
    public Player() {
        this.reset();
    }
    
    public void reset() {
        this.health = 21;
        this.shield_value = 0;
        this.potion_sickness = false;
        this.last_shield_value = 0;
        this.xp = 0;
    }
}