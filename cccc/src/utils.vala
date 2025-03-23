namespace App {
    /**
     * A class for handling fraction arithmetic in different bases
     */
    public class Fraction : Object {
        public int64 numerator { get; private set; }
        public int64 denominator { get; private set; }

        private const int MAX_BITS = 16;
        private const int64 BIT_MASK = 0xFFFF;

        /**
         * Creates a new fraction with the given numerator and denominator
         *
         * @param num The numerator value
         * @param denom The denominator value (defaults to 1)
         */
        public Fraction (int64 num, int64 denom = 1) {
            numerator = num;
            denominator = denom;
            simplify ();
        }

        /**
         * Creates a fraction from a string value in the specified base
         *
         * @param value The string representation, potentially in fraction form (with /)
         * @param base_value The numeric base (10 for decimal, 16 for hex)
         * @throws Error if parsing fails
         */
        public Fraction.from_value (string value, int base_value) throws Error {
            if (value.contains ("/")) {
                string[] parts = value.split ("/", 2);

                numerator = int64.parse (parts[0], base_value);

                if (parts.length > 1 && parts[1].length > 0) {
                    denominator = int64.parse (parts[1], base_value);
                } else {
                    denominator = 1;
                }
            } else {
                numerator = int64.parse (value, base_value);
                denominator = 1;
            }

            simplify ();
        }

        /**
         * Simplify the fraction by dividing both numerator and denominator by their GCD
         */
        public void simplify () {
            if (denominator == 0) {
                denominator = 1;
                return;
            }

            // Ensure denominator is positive
            if (denominator < 0) {
                numerator = -numerator;
                denominator = -denominator;
            }

            int64 gcd_value = gcd ((numerator < 0) ? -numerator : numerator, denominator);
            if (gcd_value > 1) {
                numerator /= gcd_value;
                denominator /= gcd_value;
            }

            // Limit to 16-bit values
            numerator &= BIT_MASK;
            denominator &= BIT_MASK;
            if (denominator == 0)denominator = 1;
        }

        /**
         * Calculate Greatest Common Divisor using Euclidean algorithm
         */
        private int64 gcd (int64 a, int64 b) {
            while (b != 0) {
                int64 t = b;
                b = a % b;
                a = t;
            }
            return a;
        }

        /**
         * Add two fractions
         */
        public Fraction add (Fraction other) {
            int64 new_num = (numerator * other.denominator) + (other.numerator * denominator);
            int64 new_denom = denominator * other.denominator;
            return new Fraction (new_num, new_denom);
        }

        /**
         * Subtract one fraction from another
         */
        public Fraction subtract (Fraction other) {
            int64 new_num = (numerator * other.denominator) - (other.numerator * denominator);
            int64 new_denom = denominator * other.denominator;
            return new Fraction (new_num, new_denom);
        }

        /**
         * Multiply two fractions
         */
        public Fraction multiply (Fraction other) {
            int64 new_num = numerator * other.numerator;
            int64 new_denom = denominator * other.denominator;
            return new Fraction (new_num, new_denom);
        }

        /**
         * Divide one fraction by another
         */
        public Fraction divide (Fraction other) {
            if (other.numerator == 0) {
                return new Fraction (0, 1); // Avoid division by zero
            }
            int64 new_num = numerator * other.denominator;
            int64 new_denom = denominator * other.numerator;
            return new Fraction (new_num, new_denom);
        }

        /**
         * Get string representation in the specified base
         */
        public string to_string_for_base (int base_value) {
            if (base_value == 10) {
                return to_decimal ();
            } else {
                return to_hex ();
            }
        }

        /**
         * Convert to hexadecimal string representation
         */
        public string to_hex () {
            if (denominator == 1) {
                // Integer case
                return (numerator & BIT_MASK).to_string ("%04X");
            } else {
                // Fraction case - represent as numerator/denominator
                return (numerator & BIT_MASK).to_string ("%X") + "/"
                       + (denominator & BIT_MASK).to_string ("%X");
            }
        }

        /**
         * Convert to decimal string representation
         */
        public string to_decimal () {
            if (denominator == 1) {
                // Integer case
                return (numerator & BIT_MASK).to_string ();
            } else {
                // Fraction case - represent as numerator/denominator
                return (numerator & BIT_MASK).to_string () + "/"
                       + (denominator & BIT_MASK).to_string ();
            }
        }

        public Fraction.from_fraction (Fraction other) {
            this.numerator = other.numerator;
            this.denominator = other.denominator;
        }

        public bool is_whole_number () {
            return denominator == 1;
        }
    }
}
