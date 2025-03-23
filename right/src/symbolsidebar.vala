public class SymbolNode {
    public string name;
    public int line;
    public SymbolType typee;
    public List<SymbolNode> children;

    public SymbolNode(string name, int line, SymbolType type) {
        this.name = name;
        this.line = line;
        this.typee = type;
        this.children = new List<SymbolNode> ();
    }

    public void add_child(SymbolNode child) {
        children.append(child);
    }
}

public enum SymbolType {
    CLASS,
    FUNCTION,
    STRUCT,
    ENUM,
    VARIABLE,
    PROPERTY
}

// Model object for the list view
public class SymbolObject : GLib.Object {
    public string name { get; set; }
    public int line { get; set; }
    public SymbolType typee { get; set; }
    public int level { get; set; } // Level for indentation

    public SymbolObject(string name, int line, SymbolType type, int level) {
        this.name = name;
        this.line = line;
        this.typee = type;
        this.level = level;
    }
}

public class SymbolSidebar : Gtk.Box {
    private Gtk.ListView list_view;
    private GLib.ListStore model;
    private GtkSource.Buffer source_buffer;
    private Gtk.SingleSelection selection_model;
    private GtkSource.View? source_view;

    public SymbolSidebar(GtkSource.View view) {
        Object(orientation : Gtk.Orientation.VERTICAL, spacing: 0);
        add_css_class("symboltree"); // Connect to CSS class

        this.source_view = view;

        // Create the model
        model = new GLib.ListStore(typeof (SymbolObject));
        selection_model = new Gtk.SingleSelection(model);

        // Create the factory using composition instead of inheritance
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect(on_setup);
        factory.bind.connect(on_bind);

        // Create the list view
        list_view = new Gtk.ListView(selection_model, factory);
        list_view.add_css_class("symbol-list");
        list_view.vexpand = true;

        // Create scrolled window
        var scrolled = new Gtk.ScrolledWindow();
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scrolled.set_child(list_view);
        scrolled.vexpand = true;

        // Add everything to the box
        append(scrolled);

        // Handle selection
        selection_model.selection_changed.connect(on_selection_changed);
    }

    // Setup callback for the factory
    private void on_setup(Gtk.SignalListItemFactory factory, GLib.Object object) {
        var list_item = (Gtk.ListItem) object;
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        box.margin_start = 8;
        box.margin_end = 8;
        box.margin_top = 4;
        box.margin_bottom = 4;

        var label = new Gtk.Label("");
        label.xalign = 0;
        label.ellipsize = Pango.EllipsizeMode.END;
        label.hexpand = true;

        box.append(label);

        list_item.set_child(box);
    }

    // Bind callback for the factory
    private void on_bind(Gtk.SignalListItemFactory factory, GLib.Object object) {
        var list_item = (Gtk.ListItem) object;
        var symbol_object = (SymbolObject) list_item.item;
        var box = (Gtk.Box) list_item.child;

        var label = (Gtk.Label) box.get_first_child();
        label.set_text(symbol_object.name);

        // Add indentation based on the level
        box.margin_start = 8 + (symbol_object.level * 16);
    }

    public void set_source_buffer(GtkSource.Buffer buffer) {
        this.source_buffer = buffer;

        // Connect to buffer changes to update the symbols
        buffer.changed.connect(update_symbols);

        // Initial update
        update_symbols();
    }

    public void set_source_view(GtkSource.View view) {
        this.source_view = view;
    }

    private void on_selection_changed(uint position, uint n_items) {
        var selected = selection_model.selected;
        if (selected < model.get_n_items()) {
            var symbol_obj = (SymbolObject) model.get_item(selected);

            if (source_buffer != null && source_view != null) {
                // Navigate to the line
                Gtk.TextIter text_iter;
                source_buffer.get_iter_at_line(out text_iter, symbol_obj.line);

                // Place cursor at the beginning of the line
                source_buffer.place_cursor(text_iter);

                // Create a mark at this position
                Gtk.TextMark mark = source_buffer.create_mark(null, text_iter, false);

                // Use scroll_mark_onscreen which is more reliable for ensuring visibility
                source_view.scroll_mark_onscreen(mark);

                // Make the line the active one in the view
                source_view.grab_focus();

                // Make sure the mark is visible with some padding
                source_view.scroll_to_mark(mark, 0.25, false, 0.0, 0.5);

                // Delete the temporary mark
                source_buffer.delete_mark(mark);
            }
        }
    }

    public void update_symbols() {
        if (source_buffer == null) {
            return;
        }

        // Clear the model
        model.remove_all();

        // Parse the buffer content for symbols
        var symbols = parse_symbols();

        // Populate the list
        populate_list(symbols);
    }

    private List<SymbolNode> parse_symbols() {
        var symbols = new List<SymbolNode> ();

        // Get the full text
        Gtk.TextIter start, end;
        source_buffer.get_bounds(out start, out end);
        string text = source_buffer.get_text(start, end, true);

        // Split into lines for analysis
        string[] lines = text.split("\n");

        // Stack to track nested symbols
        var symbol_stack = new Queue<SymbolNode> ();

        for (int i = 0; i < lines.length; i++) {
            string line = lines[i].strip();

            // Check for class definitions
            if (line.contains("class") && line.contains(":")) {
                var matches = get_text_between(line, "class", ":");
                if (matches != null && matches.length > 0) {
                    string class_name = matches[0].strip();
                    var node = new SymbolNode(class_name, i, SymbolType.CLASS);

                    if (symbol_stack.is_empty()) {
                        symbols.append(node);
                    } else {
                        symbol_stack.peek_head().add_child(node);
                    }

                    symbol_stack.push_head(node);
                }
            }
            // Check for enum definitions
            else if (line.contains("enum") && line.contains("{")) {
                var matches = get_text_between(line, "enum", "{");
                if (matches != null && matches.length > 0) {
                    string enum_name = matches[0].strip();
                    var node = new SymbolNode(enum_name, i, SymbolType.ENUM);

                    if (symbol_stack.is_empty()) {
                        symbols.append(node);
                    } else {
                        symbol_stack.peek_head().add_child(node);
                    }

                    symbol_stack.push_head(node);
                }
            }
            // Check for struct definitions
            else if (line.contains("struct") && line.contains("{")) {
                var matches = get_text_between(line, "struct", "{");
                if (matches != null && matches.length > 0) {
                    string struct_name = matches[0].strip();
                    var node = new SymbolNode(struct_name, i, SymbolType.STRUCT);

                    if (symbol_stack.is_empty()) {
                        symbols.append(node);
                    } else {
                        symbol_stack.peek_head().add_child(node);
                    }

                    symbol_stack.push_head(node);
                }
            }
            // Check for function/method definitions
            else if ((line.contains("public") || line.contains("private") || line.contains("protected") || line.contains("internal"))
                     && line.contains("(") && !line.contains(";")) {
                // This is likely a method definition
                int paren_index = line.index_of("(");
                if (paren_index > 0) {
                    string before_paren = line.substring(0, paren_index).strip();
                    string[] parts = before_paren.split(" ");

                    if (parts.length > 1) {
                        string method_name = parts[parts.length - 1];
                        var node = new SymbolNode(method_name, i, SymbolType.FUNCTION);

                        if (!symbol_stack.is_empty()) {
                            symbol_stack.peek_head().add_child(node);
                        } else {
                            symbols.append(node);
                        }
                    }
                }
            }
            // Check for property definitions
            else if ((line.contains("public") || line.contains("private")) &&
                     line.contains("get;") && line.contains("set;")) {
                string[] parts = line.split(" ");
                for (int j = 0; j < parts.length; j++) {
                    if (parts[j] == "get;" && j > 0) {
                        string prop_name = parts[j - 1];
                        var node = new SymbolNode(prop_name, i, SymbolType.PROPERTY);

                        if (!symbol_stack.is_empty()) {
                            symbol_stack.peek_head().add_child(node);
                        }
                        break;
                    }
                }
            }
            // Check for closing braces to pop the stack
            else if (line == "}") {
                if (!symbol_stack.is_empty()) {
                    symbol_stack.pop_head();
                }
            }
        }

        return symbols;
    }

    private string[] ? get_text_between(string text, string start_str, string end_str) {
        int start_index = text.index_of(start_str);
        if (start_index < 0)return null;

        start_index += start_str.length;

        int end_index = text.index_of(end_str, start_index);
        if (end_index < 0)return null;

        string middle = text.substring(start_index, end_index - start_index);
        return middle.split(",");
    }

    private void populate_list(List<SymbolNode> symbols) {
        // Flatten the tree structure for the list view
        flatten_symbols(symbols, 0);
    }

    private void flatten_symbols(List<SymbolNode> symbols, int level) {
        foreach (var symbol in symbols) {
            var symbol_obj = new SymbolObject(symbol.name, symbol.line, symbol.typee, level);
            model.append(symbol_obj);

            if (symbol.children.length() > 0) {
                flatten_symbols(symbol.children, level + 1);
            }
        }
    }
}
