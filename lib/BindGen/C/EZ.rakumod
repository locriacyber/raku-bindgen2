my $re_color = rx:P5/(\d+), (\d+), (\d+), (\d+)/;

sub startswith (Str $s, Str $prefix) { $s.substr(0, $prefix.chars) eq $prefix }

sub deduce_prefix(@names) {
    PRE +@names > 0;
    my $ref = @names[0];
    my $longest = '';
    for 1..Inf -> $i {
        my $prefix = $ref.substr(0, $i);
        last unless @names».&startswith($prefix).all;
        $longest = $prefix;
    }
    $longest.substr(0, $longest.chars - 1)
}

sub remove_prefix(Str $name, Str $prefix) {
    $name.substr($prefix.chars + 1)
}

class RaylibBindingGenerator {
    has IO::Handle $.io is required;

    method TWEAK {
        self.append-line: 'use NativeCall;'
    }

    method append-line (Str $line, Str :$desc) {
        if $desc {
            my $ws = ($line ~~ rx/^(\s*)/)[0];
            $!io.print: $ws ~ "#|" ~ $desc ~ "\n" if $desc;
        }
        $!io.print: $line ~ "\n";
    }

    multi method parse-element ('Define', $el) {
        given $el<type>.Str {
            my $desc = $el<desc>;
            my $name = $el<name>;
            when 'COLOR' {
                given $el<value> ~~ $re_color {
                    self.append-line: :$desc, "constant Color::$name = Color.new(:$_[0]r :$_[1]g :$_[2]b :$_[3]a);";
                }
            }
            when 'FLOAT' {
                self.append-line("#|$desc") if $desc;
                my $value = $el<value>;
                self.append-line: :$desc, "constant $name = $value;";
            }
            when 'FLOAT_MATH' {
                self.append-line("#|$desc") if $desc;
                my $value = $el<value>;
                $value ~~ s/(\d+)f/$0/;
                self.append-line: :$desc, "constant $name = $value;";
            }
        }
    }

    multi method parse-element ('Enum', $el) {
        my $prefix = deduce_prefix($el.children».<name>);
        self.append-line: :desc($el<desc>), "constant $prefix is export = $el<name>;";
        self.append-line: "enum $el<name> \{";
        for $el.children -> $elc {
            PRE $elc.tag ~~ 'Value';
            my $name = remove_prefix($elc<name>, $prefix);
            self.append-line: :desc($elc<desc>), "    $name => $elc<integer>,";
        }
        self.append-line: "\}";
    }

    multi method parse-element ('Struct', $el) {
        self.append-line: :desc($el<desc>), "class $el<name> is repr('CStruct') is export \{";
        for $el.children -> $elc {
            PRE $elc.tag ~~ 'Field';
            ...
            # HAS num32 $.x;
            # HAS Vector2 $.pos;
            # HAS Pointer $.data;
            # HAS Pointer[num32] $.vertices
            # HAS Pointer[Pointer[Transform]] $.transform;
            # HAS Matrix @.projection[2] is CArray;

            # my $name = remove_prefix($elc<name>, $prefix);
            # self.append-line: :desc($elc<desc>), "    constant $name = $elc<integer>;";
        }
        self.append-line: "\}";
    }

    multi method parse-element ('Alias', $el) {
        # TODO
    }

    multi method parse-element ('Function', $el) {
        # TODO
    }

    multi method parse-element ('Callback', $el) {
        # TODO
    }
}

constant @parse-order = <Define Enum Struct Alias Function Callback>;

sub parse-raylib-xml (IO :$input, IO :$io) is export {
    use DOM::Tiny;
    my $dom = DOM::Tiny.parse(:xml, $input.slurp);
    say $dom.WHAT;
    my $ctx = RaylibBindingGenerator.new(io => $io.open(:w));
    for @parse-order -> $tag_name {
        for $dom.find($tag_name) -> $el {
            $ctx.parse-element($tag_name, $el);
        }
    }
    # for $dom ->
    say $dom.WHAT;
    # my LibXML::Reader $reader .= new(file => "file.xml")
    # my $doc = LibXML.parse(io => $xml_file);
    # my @decls = gather {
    #     for $doc.root.children {
    #         for $_.children {
    #             take $_;
    #         }
    #     }
    # };
    # sub parse-order (Str $name) {
    #     $parse-order.first($name):k
    # }
    # sub is-tag-name-valid (Str $name) {
    #     $parse-order.first($name).defined or warn "Unexpected XML element: $name"
    # }
    # my @decl_pairs = @decls.classify({ .name }).grep({ is-tag-name-valid(.key) }).sort({ parse-order(.key) });

    # my $ctx = RaylibBindingGenerator.new(io => $io.open(:w));

    # for @decl_pairs -> (:key($tag_name), :value(@els)) {
    #     $ctx.parse-element($tag_name, $_) for @els;
    # }

    $ctx
}
