using Gtk;

// Data structure for icon storage
public class IconData {
    public string[] rows;
    public int x;
    public int y;
    
    public IconData(string[] iconRows, int posX, int posY) {
        rows = iconRows;
        x = posX;
        y = posY;
    }
}

// Expression evaluation class for BASIC language
public class ExpressionEvaluator {
    private string expression;
    private int position;
    private string currentToken;
    
    // Reference to the application to access variables
    private BasicEmulator app;
    
    public ExpressionEvaluator(string expr, BasicEmulator application) {
        expression = expr;
        app = application;
        position = 0;
        nextToken();
    }
    
    private void nextToken() {
        // Skip whitespace
        while (position < expression.length && expression[position].isspace()) {
            position++;
        }
        
        if (position >= expression.length) {
            currentToken = "";
            return;
        }
        
        if (expression[position].isalpha()) {
            // Variable or keyword
            int start = position;
            while (position < expression.length && (expression[position].isalpha() || expression[position].isdigit())) {
                position++;
            }
            currentToken = expression.substring(start, position - start);
        } else if (expression[position].isdigit() || expression[position] == '.') {
            // Number
            int start = position;
            while (position < expression.length && (expression[position].isdigit() || expression[position] == '.')) {
                position++;
            }
            currentToken = expression.substring(start, position - start);
        } else if (expression[position] == '"') {
            // String literal
            int start = position;
            position++; // Skip opening quote
            while (position < expression.length && expression[position] != '"') {
                position++;
            }
            if (position < expression.length) {
                position++; // Skip closing quote
            }
            currentToken = expression.substring(start, position - start);
        } else {
            // Operator or special character
            currentToken = expression[position].to_string();
            position++;
            
            // Handle two-character operators (>=, <=, ==, <>)
            if (position < expression.length) {
                string twoChar = currentToken + expression[position].to_string();
                if (twoChar == ">=" || twoChar == "<=" || twoChar == "==" || twoChar == "<>") {
                    currentToken = twoChar;
                    position++;
                }
            }
        }
    }
    
    public double evaluate() {
        double result = parseExpression();
        return result;
    }
    
    private double parseExpression() {
        double left = parseTerm();
        
        while (currentToken == "+" || currentToken == "-" || 
               currentToken == "AND" || currentToken == "OR") {
            string op = currentToken;
            nextToken();
            double right = parseTerm();
            
            switch (op) {
                case "+":
                    left = left + right;
                    break;
                case "-":
                    left = left - right;
                    break;
                case "AND":
                    left = (left != 0 && right != 0) ? 1 : 0;
                    break;
                case "OR":
                    left = (left != 0 || right != 0) ? 1 : 0;
                    break;
            }
        }
        
        return left;
    }
    
    private double parseTerm() {
        double left = parseFactor();
        
        while (currentToken == "*" || currentToken == "/" || currentToken == "^") {
            string op = currentToken;
            nextToken();
            double right = parseFactor();
            
            switch (op) {
                case "*":
                    left = left * right;
                    break;
                case "/":
                    if (right == 0) {
                        // Prevent division by zero
                        left = 0;
                    } else {
                        left = left / right;
                    }
                    break;
                case "^":
                    left = Math.pow(left, right);
                    break;
            }
        }
        
        return left;
    }
    
    private double parseFactor() {
        double value = 0.0;
    
        if (currentToken == "(") {
            nextToken();
            double result = parseExpression();
            
            if (currentToken == ")") {
                nextToken();
            } else {
                // Unmatched parenthesis, but we'll continue
            }
            
            return result;
        } else if (currentToken == "NOT") {
            nextToken();
            double operand = parseFactor();
            return (operand == 0) ? 1 : 0;
        } else if (currentToken == "-") {
            nextToken();
            return -parseFactor();
        } else if (currentToken == "+") {
            nextToken();
            return parseFactor();
        } else if (currentToken.has_prefix("\"") && currentToken.has_suffix("\"")) {
            currentToken.substring(1, currentToken.length - 2);
            nextToken();
            return 0; // Return 0 for strings in numeric context
        } else if (double.try_parse(currentToken, out value)) {
            nextToken();
            return value;
        } else if (app.variables.contains(currentToken)) {
            string varName = currentToken;
            nextToken();
            return app.get_variable(varName);
        } else {
            // Unknown token, treat as 0
            nextToken();
            return 0;
        }
    }
    
    public bool evaluateComparison() {
        double left = parseExpression();
        
        if (currentToken == "=" || currentToken == "==" || 
            currentToken == "<" || currentToken == ">" || 
            currentToken == "<=" || currentToken == ">=" || 
            currentToken == "<>") {
            string op = currentToken;
            nextToken();
            double right = parseExpression();
            
            switch (op) {
                case "=":
                case "==":
                    return left == right;
                case "<":
                    return left < right;
                case ">":
                    return left > right;
                case "<=":
                    return left <= right;
                case ">=":
                    return left >= right;
                case "<>":
                    return left != right;
                default:
                    return false;
            }
        }
        
        // If there's no comparison operator, treat non-zero as true
        return left != 0;
    }
}