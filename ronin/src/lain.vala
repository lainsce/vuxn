/**
 * Vala translation of the Lain LISP interpreter.
 */
using GLib;
using Gee;

// --- Error Handling ---
public errordomain LispError {
    SYNTAX,
    RUNTIME,
    TYPE
}

// --- LISP Value Representation ---
public abstract class LispValue : Object {
    public virtual string to_string() { return "(LispValue)"; }
}

public class LispNil : LispValue {
    public override string to_string() { return "nil"; }
}

public class LispValaObject : LispValue {
    public GLib.Object vala_object { get; private set; }
    public string object_type { get; private set; }

    public LispValaObject(GLib.Object obj) {
        this.vala_object = obj;
        this.object_type = obj.get_type().name();
    }

    public override string to_string() {
        return @"<Vala:$object_type>";
    }
}

public class LispNumber : LispValue {
    public double value { get; set; }
    public LispNumber(double val) {
        value = val;
    }

    public override string to_string() { return value.to_string(); }
}

public class LispString : LispValue {
    public string value { get; set; }
    public LispString(string val) {
        value = val;
    }

    public override string to_string() { return "\"" + value + "\""; }
}

public class LispBool : LispValue {
    public bool value { get; set; }
    public LispBool(bool val) {
        value = val;
    }

    public override string to_string() { return value ? "true" : "false"; }
}

public class LispIdentifier : LispValue {
    public string value { get; set; }
    public LispIdentifier(string val) {
        value = val;
    }

    public override string to_string() { return value; }
}

public class LispSymbol : LispValue {
    public string? host { get; set; default = null; }
    public string value { get; set; }

    public LispSymbol(string val, string? host_val = null) {
        value = val;
        host = host_val;
    }

    public override string to_string() {
        if (host != null) {
            return host + ":" + value;
        }
        return ":" + value;
    }
}

public class LispList : LispValue {
    public ArrayList<LispValue> list { get; set; }

    public LispList() {
        list = new ArrayList<LispValue> ();
    }

    public override string to_string() {
        var parts = new ArrayList<string> ();
        foreach (var item in list) {
            parts.add(item.to_string());
        }
        return "(" + string.joinv(" ", parts.to_array()) + ")";
    }
}

// Represents a Vala function callable from LISP
public delegate LispValue BuiltinFuncDelegate(ArrayList<LispValue> args) throws LispError;

public class LispBuiltinFunc : LispValue {
    public BuiltinFuncDelegate func;

    public LispBuiltinFunc(BuiltinFuncDelegate f) {
        func = f;
    }

    public LispValue call(ArrayList<LispValue> args) throws LispError {
        return func(args);
    }

    public override string to_string() { return "(BuiltinFunc)"; }
}

// Represents a LISP function defined with defn or λ
public class LispLambda : LispValue {
    public ArrayList<LispIdentifier> parameters;
    public LispList body; // List of expressions
    public LispContext closure_context; // Context where defined

    public LispLambda(ArrayList<LispIdentifier> p, LispList b, LispContext closure_ctx) {
        parameters = p;
        body = b;
        closure_context = closure_ctx;
    }

    public LispValue call(ArrayList<LispValue> args, LispContext call_context) throws LispError {
        if (args.size != parameters.size) {
            throw new LispError.RUNTIME("Lambda expects %d args, got %d".printf(parameters.size, args.size));
        }

        // Create a new context for the lambda execution
        var lambda_exec_context = new LispContext(closure_context); // Chain to definition context

        // Bind arguments to parameters in the new context
        for (int i = 0; i < parameters.size; i++) {
            lambda_exec_context.define(parameters.get(i).value, args.get(i));
        }

        // Evaluate the body expressions in the new context
        LispValue? last_result = null;
        foreach (var expr in body.list) {
            last_result = Lain.interpret(expr, lambda_exec_context);
        }

        return last_result ?? new LispNil();
    }

    public override string to_string() { return "(Lambda)"; }
}


// --- Context / Scope ---
public class LispContext : Object {
    public HashTable<string, LispValue> scope;
    public LispContext? parent;

    public LispContext(LispContext? parent = null) {
        this.parent = parent;
        scope = new HashTable<string, LispValue> (str_hash, str_equal);
    }

    public void define(string name, LispValue value) {
        scope.set(name, value);
    }

    public new LispValue ? get(string identifier) {
        if (scope.contains(identifier)) {
            return scope.get(identifier);
        } else if (parent != null) {
            return parent.get(identifier);
        } else {
            return null;
        }
    }
}


// --- Lain Interpreter Class ---
public class Lain : Object {

    private LispContext root_context;

    // Constructor - takes the library of built-in functions
    public Lain(HashTable<string, LispValue>? lib = null) {
        root_context = new LispContext();

        print("Initializing Lain interpreter\n");

        if (lib != null) {
            // Populate root context with library functions
            lib.foreach((name, func) => {
                root_context.define(name, func);
                print("Added function: %s\n", name);
            });
            print("Added %u library functions\n", lib.size());
        } else {
            print("No library functions provided\n");
        }

        print("Lain interpreter initialized with root context: %p\n", root_context);
    }

    // Helper method to split LISP code into complete expressions
    private ArrayList<string> split_to_expressions(string input) {
        var expressions = new ArrayList<string> ();

        // State machine to track parentheses balancing
        int paren_level = 0;
        bool in_string = false;
        bool in_comment = false;
        var current = new StringBuilder();

        foreach (char c in input.to_utf8()) {
            // Add character to current buffer
            current.append_c(c);

            if (c == '\n') {
                in_comment = false; // End of comment line
            } else if (in_comment) {
                // Skip processing while in a comment
                continue;
            } else if (in_string) {
                if (c == '"') {
                    in_string = false; // End of string
                }
            } else if (c == '"') {
                in_string = true; // Start of string
            } else if (c == ';') {
                in_comment = true; // Start of comment
            } else if (c == '(') {
                paren_level++;
            } else if (c == ')') {
                paren_level--;

                // If we've closed all parentheses, we've completed an expression
                if (paren_level == 0) {
                    string expr = current.str.strip();
                    if (expr != "") {
                        expressions.add(expr);
                    }
                    current = new StringBuilder();
                }
            }
        }

        // Add any remaining complete expressions
        string remaining = current.str.strip();
        if (paren_level == 0 && remaining != "") {
            expressions.add(remaining);
        }

        return expressions;
    }

    // --- Tokenizer ---
    private static ArrayList<string> tokenize(string input) throws LispError {
        // Remove comments and prepare input for tokenization
        var lines = input.split("\n");
        var comment_free = new StringBuilder();

        foreach (var line in lines) {
            var comment_idx = line.index_of(";");
            if (comment_idx >= 0) {
                comment_free.append(line.substring(0, comment_idx));
            } else {
                comment_free.append(line);
            }
            comment_free.append("\n");
        }

        var processed = comment_free.str
             .replace("(", " ( ")
             .replace(")", " ) ");

        // Handle strings - preserve spaces inside quotes
        var string_parts = processed.split("\"");
        var rebuilt_tokens = new StringBuilder();
        for (int i = 0; i < string_parts.length; i++) {
            if (i % 2 == 0) { // Outside quotes
                rebuilt_tokens.append(string_parts[i]);
            } else { // Inside quotes - keep as single token, mark spaces
                rebuilt_tokens.append("\"");
                rebuilt_tokens.append(string_parts[i].replace(" ", "!ws!"));
                rebuilt_tokens.append("\"");
            }
        }
        processed = rebuilt_tokens.str;

        string[] tokens_array = processed.strip().split_set(" \t\n\r"); // Split by whitespace

        var tokens = new ArrayList<string> ();
        foreach (string token in tokens_array) {
            if (token.strip() != "") {
                tokens.add(token.replace("!ws!", " ")); // Restore spaces in strings
            }
        }
        return tokens;
    }

    // --- Categorizer ---
    private static LispValue categorize(string token) throws LispError {
        double num;
        if (double.try_parse(token, out num)) {
            return new LispNumber(num);
        } else if (token.has_prefix("\"") && token.has_suffix("\"")) {
            if (token.length < 2)throw new LispError.SYNTAX("Empty string literal");
            return new LispString(token.substring(1, token.length - 2));
        } else if (token == "true" || token == "false") {
            return new LispBool(token == "true");
        } else if (token.has_prefix(":")) {
            if (token.length < 2)throw new LispError.SYNTAX("Empty symbol literal");
            return new LispSymbol(token.substring(1));
        } else if (token.index_of(":") > 0) {
            string[] parts = token.split(":", 2);
            return new LispSymbol(parts[1], parts[0]);
        } else if (token == "nil") {
            return new LispNil();
        } else {
            return new LispIdentifier(token);
        }
    }

    // --- Parser ---
    private static LispValue parse(ArrayList<string> tokens) throws LispError {
        if (tokens.size == 0) {
            throw new LispError.SYNTAX("Unexpected end of input");
        }

        var token_list = new ArrayList<string> ();
        // Copy all tokens to a new list so we can use a simpler approach
        foreach (var token in tokens) {
            token_list.add(token);
        }

        return read_from_tokens(token_list);
    }

    private static LispValue read_from_tokens(ArrayList<string> tokens) throws LispError {
        if (tokens.size == 0) {
            throw new LispError.SYNTAX("Unexpected end of input");
        }

        string token = tokens.remove_at(0); // Get and remove the first token

        if (token == "(") {
            var list = new LispList();
            while (tokens.size > 0 && tokens[0] != ")") {
                list.list.add(read_from_tokens(tokens));
            }

            if (tokens.size == 0) {
                throw new LispError.SYNTAX("Unexpected end of list, missing ')'");
            }

            tokens.remove_at(0); // Remove the closing ')'
            return list;
        } else if (token == ")") {
            throw new LispError.SYNTAX("Unexpected ')'");
        } else {
            return categorize(token);
        }
    }

    // --- Evaluator ---
    public static LispValue interpret(LispValue input, LispContext context) throws LispError {
        if (input is LispList) {
            LispList list = (LispList) input;
            return interpret_list(list, context);
        } else if (input is LispIdentifier) {
            LispIdentifier id = (LispIdentifier) input;
            var value = context.get(id.value);
            if (value == null)throw new LispError.RUNTIME("Unknown identifier: " + id.value);
            return value;
        } else if (input is LispSymbol) {
            LispSymbol sym = (LispSymbol) input;
            // Special handling for host:value symbols (used as getters)
            if (sym.host != null) {
                var host_obj = context.get(sym.host);
                if (host_obj == null) {
                    throw new LispError.RUNTIME("Unknown host object: " + sym.host);
                }

                // If host is a list, try to get the value from it
                if (host_obj is LispList) {
                    LispList host_list = (LispList) host_obj;
                    int index;
                    if (int.try_parse(sym.value, out index) && index >= 0 && index < host_list.list.size) {
                        return host_list.list[index];
                    }
                }

                // For other types of host objects, we'd need to implement specific accessors
                throw new LispError.RUNTIME("Cannot access property " + sym.value + " of " + sym.host);
            }

            // Regular symbol (without host) evaluates to itself
            return input;
        } else { // Literals (Number, String, Bool, Nil) evaluate to themselves
            return input;
        }
    }

    private static LispValue interpret_list(LispList list, LispContext context) throws LispError {
        if (list.list.size == 0) {
            return new LispNil();
        }

        var first = list.list.get(0);

        // Special forms take precedence over function calls
        if (first is LispIdentifier) {
            LispIdentifier id = (LispIdentifier) first;

            print("Evaluating list with first element: %s\n", id.value);

            // Check for Special Forms
            switch (id.value) {
            case "if" : return eval_if(list, context);
            case "let" : return eval_let(list, context);
            case "def" : return eval_def(list, context);
            case "defn":   return eval_defn(list, context);
            case "lambda":
            case "fn":
            case "λ":      return eval_lambda(list, context);
            }

            // First check if this is a defined function in the context
            var func = context.get(id.value);
            if (func == null) {
                print("ERROR: Unknown identifier: %s\n", id.value);
                print("Context contains:\n");
                // List contents of root context for debugging
                if (context.scope != null) {
                    context.scope.foreach((key, val) => {
                        print("  %s: %s\n", key, val.to_string());
                    });
                }

                throw new LispError.RUNTIME("Unknown identifier: " + id.value);
            }
        }

        // If not a special form, it's a function call
        // Evaluate the first element to get the procedure (function)
        var proc_val = interpret(first, context);

        // Evaluate arguments
        var args = new ArrayList<LispValue> ();
        for (int i = 1; i < list.list.size; i++) {
            args.add(interpret(list.list.get(i), context));
        }

        // Call the procedure
        if (proc_val is LispLambda) {
            LispLambda lambda = (LispLambda) proc_val;
            return lambda.call(args, context); // Call user-defined lambda
        } else if (proc_val is LispBuiltinFunc) {
            LispBuiltinFunc builtin = (LispBuiltinFunc) proc_val;
            return builtin.call(args); // Call Vala built-in function
        } else {
            throw new LispError.RUNTIME("First element is not callable: " + proc_val.to_string());
        }
    }

    // --- Special Form Handlers ---

    private static LispValue eval_if(LispList list, LispContext context) throws LispError {
        // (if condition then_expr else_expr)
        if (list.list.size < 3 || list.list.size > 4) {
            throw new LispError.SYNTAX("Invalid 'if' format: requires 2 or 3 arguments");
        }
        var condition_val = interpret(list.list.get(1), context);

        // Define truthiness: false and nil are false, everything else is true
        bool is_true = true;
        if (condition_val is LispBool) {
            LispBool b = (LispBool) condition_val;
            if (!b.value)is_true = false;
        }
        if (condition_val is LispNil)is_true = false;

        if (is_true) {
            return interpret(list.list.get(2), context); // Then expression
        } else if (list.list.size == 4) {
            return interpret(list.list.get(3), context); // Else expression
        } else {
            return new LispNil(); // No else expression, return nil
        }
    }

    private static LispValue eval_let(LispList list, LispContext context) throws LispError {
        // (let ((var1 val1) (var2 val2)) body...)
        if (list.list.size < 3 || !(list.list.get(1) is LispList)) {
            throw new LispError.SYNTAX("Invalid 'let' format: requires bindings list and body");
        }

        LispList bindings_list = (LispList) list.list.get(1);
        var let_context = new LispContext(context); // Create new context chained to parent

        foreach (var binding in bindings_list.list) {
            if (!(binding is LispList)) {
                throw new LispError.SYNTAX("Invalid 'let' binding format: requires (identifier value) pairs");
            }
            LispList pair = (LispList) binding;
            if (pair.list.size != 2 || !(pair.list.get(0) is LispIdentifier)) {
                throw new LispError.SYNTAX("Invalid 'let' binding format: requires (identifier value) pairs");
            }
            LispIdentifier id = (LispIdentifier) pair.list.get(0);
            var value = interpret(pair.list.get(1), context); // Evaluate value in *outer* context
            let_context.define(id.value, value);
        }

        // Evaluate body expressions in the new let_context
        LispValue? last_result = null;
        for (int i = 2; i < list.list.size; i++) {
            last_result = interpret(list.list.get(i), let_context);
        }
        return last_result ?? new LispNil(); // Return last result or Nil
    }

    private static LispValue eval_def(LispList list, LispContext context) throws LispError {
        // (def name value)
        if (list.list.size != 3) {
            throw new LispError.SYNTAX("Invalid 'def' format: requires identifier and value");
        }

        // We need to validate that the second item is an identifier
        var name_expr = list.list.get(1);

        // Test that the name is an identifier
        if (!(name_expr is LispIdentifier)) {
            throw new LispError.SYNTAX("Invalid 'def' format: requires identifier (got "
                                       + name_expr.get_type().name() + ")");
        }

        LispIdentifier id = (LispIdentifier) name_expr;

        // Now interpret the value
        var value = interpret(list.list.get(2), context);

        // Define the variable in the context
        context.define(id.value, value);

        // Print for debugging
        print("Defined variable '%s' with value: %s\n", id.value, value.to_string());

        return value; // def returns the assigned value
    }

    private static LispValue eval_defn(LispList list, LispContext context) throws LispError {
        // (defn name (param1 param2) body...)
        // Or (defn name docstring (param1 param2) body...)
        if (list.list.size < 4) {
            throw new LispError.SYNTAX("Invalid 'defn' format: defn name params body...");
        }
        if (!(list.list.get(1) is LispIdentifier)) {
            throw new LispError.SYNTAX("Invalid 'defn' format: name must be an identifier");
        }

        LispIdentifier fn_name_id = (LispIdentifier) list.list.get(1);
        string fn_name = fn_name_id.value;

        int params_index = 2;
        // Skip optional docstring
        if (list.list.get(2) is LispString) {
            if (list.list.size < 5)throw new LispError.SYNTAX("Invalid 'defn' format with docstring");
            params_index = 3;
        }

        if (!(list.list.get(params_index) is LispList)) {
            throw new LispError.SYNTAX("Invalid 'defn' format: parameters must be a list");
        }

        LispList params_list_val = (LispList) list.list.get(params_index);

        // Extract parameter identifiers
        var parameters = new ArrayList<LispIdentifier> ();
        foreach (var p in params_list_val.list) {
            if (!(p is LispIdentifier)) {
                throw new LispError.SYNTAX("Invalid 'defn' format: parameters must be identifiers");
            }
            LispIdentifier pid = (LispIdentifier) p;
            parameters.add(pid);
        }

        // Body starts after parameters
        var body = new LispList();
        for (int i = params_index + 1; i < list.list.size; i++) {
            body.list.add(list.list.get(i));
        }

        // Create lambda and define it in the current context
        var lambda = new LispLambda(parameters, body, context); // Capture current context
        context.define(fn_name, lambda);

        return lambda; // defn returns the created lambda
    }

    private static LispValue eval_lambda(LispList list, LispContext context) throws LispError {
        // (lambda (param1 param2) body...)
        // Or (fn (param1 param2) body...) etc.
        if (list.list.size < 3 || !(list.list.get(1) is LispList)) {
            throw new LispError.SYNTAX("Invalid lambda/fn format: requires parameters list and body");
        }

        LispList params_list_val = (LispList) list.list.get(1);

        // Extract parameter identifiers
        var parameters = new ArrayList<LispIdentifier> ();
        foreach (var p in params_list_val.list) {
            if (!(p is LispIdentifier)) {
                throw new LispError.SYNTAX("Invalid lambda/fn format: parameters must be identifiers");
            }
            LispIdentifier pid = (LispIdentifier) p;
            parameters.add(pid);
        }

        // Body starts at index 2
        var body = new LispList();
        for (int i = 2; i < list.list.size; i++) {
            body.list.add(list.list.get(i));
        }

        // Create and return lambda, capturing current context
        return new LispLambda(parameters, body, context);
    }

    // --- Public Run Method ---
    public LispValue ? run(string input) throws Error {
        try {
            print("Lain.run called with input: %s\n", input);

            // Split input into complete LISP expressions
            var expressions = split_to_expressions(input);
            print("Split into %d expressions\n", expressions.size);

            // Process each expression
            LispValue? last_result = null;
            foreach (var expr_str in expressions) {
                print("Processing expression: %s\n", expr_str);

                // 1. Tokenize
                var tokens = tokenize(expr_str);
                if (tokens.size == 0) {
                    print("Empty expression, skipping\n");
                    continue;
                }

                print("Tokenized to %d tokens\n", tokens.size);

                // 2. Parse
                var expr = parse(tokens);
                print("Parsed expression: %s\n", expr.to_string());

                // 3. Interpret
                print("Interpreting with root context: %p\n", root_context);
                if (root_context == null || root_context.scope == null) {
                    print("ERROR: Invalid root context\n");
                    throw new LispError.RUNTIME("Invalid interpreter state: root context is null");
                }

                last_result = interpret(expr, root_context);
                print("Interpretation result: %s\n", last_result != null ? last_result.to_string() : "null");
            }

            return last_result; // Return the result of the last expression
        } catch (LispError e) {
            print("LispError: %s\n", e.message);
            throw e; // Re-throw LispError for handling by caller
        } catch (Error e) {
            print("Error in Lain.run: %s\n", e.message);
            throw new LispError.RUNTIME("Error running LISP code: " + e.message);
        }
    }
}
