package GetHashVar::Tags;
use strict;
no warnings 'redefine';
use Data::Dumper;
{
    package Data::Dumper;
    sub qquote { return shift; }
}
$Data::Dumper::Useperl = 1;
$Data::Dumper::Maxdepth = 10;
use Time::HiRes qw( usleep );

sub _hdlr_set_hash_vars {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $val = $ctx->slurp( $args );
    $val =~ s/(^\s+|\s+$)//g;
    my @pairs = split /\r?\n/, $val;
    foreach my $line ( @pairs ) {
        next if $line =~ m/^\s*$/;
        my ( $var, $value ) = split /\s*=/, $line, 2;
        unless ( defined( $var ) && defined( $value ) ) {
            return $ctx->error( "Invalid variable assignment: $line" );
        }
        $var =~ s/^\s+//;
        $ctx->stash( 'vars' )->{ $name }->{ $var } = $value;
    }
    return '';
}

sub _hdlr_loop_with_sort {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $kind = $args->{ kind } || 'numeric';
    my $scope = $args->{ scope } || 'key';
    if ( $scope eq 'value' ) {
        $scope = 'var';
    }
    my $order = $args->{ order } || 'ascend';
    my $tokens = $ctx->stash( 'tokens' );
    my $builder = $ctx->stash( 'builder' );
    my @vars;
    my $array = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $array ) eq 'HASH' ) {
        if ( ( $kind eq 'string' ) &&
            ( $scope eq 'key' ) && ( $order eq 'ascend' ) ) {
            for my $key ( sort keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'str' ) &&
            ( $scope eq 'key' ) && ( $order eq 'descend' ) ) {
            for my $key ( sort { $b cmp $a } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'str' ) &&
            ( $scope eq 'var' ) && ( $order eq 'ascend' ) ) {
            for my $key ( sort { $array->{ $a } cmp $array->{ $b } } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'str' ) &&
            ( $scope eq 'var' ) && ( $order eq 'descend' ) ) {
            for my $key ( sort { $array->{ $b } cmp $array->{ $a } } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'num' ) &&
            ( $scope eq 'key' ) && ( $order eq 'ascend' ) ) {
            for my $key ( sort { $a <=> $b } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'num' ) &&
            ( $scope eq 'key' ) && ( $order eq 'descend' ) ) {
            for my $key ( sort { $a <=> $b } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'num' ) &&
            ( $scope eq 'var' ) && ( $order eq 'ascend' ) ) {
            for my $key ( sort { $array->{ $a } <=> $array->{ $b } } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } elsif ( ( $kind eq 'num' ) &&
            ( $scope eq 'var' ) && ( $order eq 'descend' ) ) {
            foreach my $key ( sort { $array->{ $b } <=> $array->{ $a } } keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        } else {
            for my $key ( keys %$array ) {
                push ( @vars, { $key => $array->{ $key } } );
            }
        }
    } elsif ( ( ref $array ) eq 'ARRAY' ) {
        @vars = @$array;
        if ( ( $kind eq 'str' ) && ( $order eq 'ascend' ) ) {
            @vars = sort { $a cmp $b } @vars;
        } elsif ( ( $kind eq 'str' ) && ( $order eq 'descend' ) ) {
            @vars = sort { $b cmp $a } @vars;
        } elsif ( ( $kind eq 'num' ) && ( $order eq 'ascend' ) ) {
            @vars = sort { $a <=> $b } @vars;
        } elsif ( ( $kind eq 'num' ) && ( $order eq 'descend' ) ) {
            @vars = sort { $b <=> $a } @vars;
        }
    }
    my $res = '';
    my $i = 0;
    my $odd = 1; my $even = 0;
    for my $var ( @vars ) {
        local $ctx->{ __stash }->{ vars }->{ __first__ } = 1 if ( $i == 0 );
        local $ctx->{ __stash }->{ vars }->{ __counter__ } = $i + 1;
        local $ctx->{ __stash }->{ vars }->{ __odd__ } = $odd;
        local $ctx->{ __stash }->{ vars }->{ __even__ } = $even;
        local $ctx->{ __stash }->{ vars }->{ __last__ } = 1 if ( !defined( $vars[ $i + 1 ] ) );
        my ( $key, $value );
        if ( ( ref $var ) && ( ref $var ) eq 'HASH' ) {
            for my $_key ( keys %$var ) {
                $key = $_key;
                $value = $var->{ $_key };
            }
        } else {
            $key = $i;
            $value = $var;
        }
        local $ctx->{ __stash }->{ vars }->{ __key__ } = $key;
        local $ctx->{ __stash }->{ vars }->{ __value__ } = $value;
        my $out = $builder->build( $ctx, $tokens, $cond );
        if ( !defined( $out ) ) { return $ctx->error( $builder->errstr ) };
        $res .= $out;
        if ( $odd == 1 ) { $odd = 0 } else { $odd = 1 };
        if ( $even == 1 ) { $even = 0 } else { $even = 1 };
        $i++;
    }
    return $res;
}

sub _hdlr_yaml_to_vars {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' };
    my $yaml = $ctx->slurp( $args );
    my $array = MT::Util::YAML::Load( $yaml );
    if ( $name ) {
        $ctx->stash( 'vars' )->{ $name } = $array;
    } else {
        if ( ( ref $array ) eq 'HASH' ) {
            for my $key ( keys %$array ) {
                $ctx->stash( 'vars' )->{ $key } = $array->{ $key };
            }
        }
    }
    return '';
}

sub _hdlr_usleep {
    my ( $ctx, $args, $cond ) = @_;
    my $microseconds = $args->{ 'microseconds' } || return '';
    $microseconds = $microseconds * 1;
    usleep( $microseconds * 1000 );
    return '';
}

sub _hdlr_key_exists {
    my $value = _hdlr_get_hash_var( @_ );
    if ( $value ) {
        return 1;
    }
    return 0;
}

sub _hdlr_value_exists {
    my $key = _hdlr_get_hash_key( @_ );
    if ( $key ) {
        return 1;
    }
    return 0;
}

sub _hdlr_is_scalar {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return 0;
    my $var = $ctx->stash( 'vars' )->{ $name };
    if ( defined( $var ) ) {
        if ( ref $var ) {
            return 0;
        }
        return 1;
    }
    return 0;
}

sub _hdlr_is_array {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return 0;
    my $var = $ctx->stash( 'vars' )->{ $name };
    if ( defined( $var ) ) {
        if ( ( ref $var ) eq 'ARRAY' ) {
            return 1;
        }
    }
    return 0;
}

sub _hdlr_is_hash {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return 0;
    my $var = $ctx->stash( 'vars' )->{ $name };
    if ( defined( $var ) ) {
        if ( ( ref $var ) eq 'HASH' ) {
            return 1;
        }
    }
    return 0;
}

sub _hdlr_in_array {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $value = $args->{ 'value' };
    if (! $value ) {
        $value = $args->{ 'var' } || return '';
    }
    my $array = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $array ) eq 'ARRAY' ) {
        if ( grep( /^$value$/, @$array ) ) {
            return 1;
        }
    }
    return 0;
}

sub _hdlr_get_array_var {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $num = $args->{ 'num' };
    my $index = $args->{ 'index' };
    if ( (! defined( $index ) ) && (! $num ) ) {
        return '';
    }
    if ( $num ) {
        $index = $num - 1;
    }
    my $array = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $array ) eq 'ARRAY' ) {
        return @$array[ $index ];
    } elsif ( ( ref $array ) eq 'HASH' ) {
        my $scope = $args->{ 'scope' } || 'key';
        my $i = 0;
        for my $key ( keys %$array ) {
            if ( $i == $index ) {
                if ( $scope eq 'key' ) {
                    return $key;
                } else {
                    return $array->{ $key };
                }
            }
            $i++;
        }
    }
}

sub _hdlr_get_hash_var {
    my ( $ctx, $args, $cond ) = @_;
    my $key = $args->{ 'key' } || return '';
    my $name = $args->{ 'name' } || return '';
    my $hash = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $hash ) eq 'HASH' ) {
        if ( ( ref $key ) && ( ( ref $key ) eq 'ARRAY' ) ) {
            my $value = $hash;
            for my $_key ( @$key ) {
                if ( ( ref $value ) &&
                    ( ( ref $value ) eq 'ARRAY' ) ) {
                    $value = @$value[ $_key ];
                } else {
                    $value = $value->{ $_key };
                }
            }
            return $value;
        }
        return $hash->{ $key };
    }
    return '';
}

sub _hdlr_get_hash_key {
    my ( $ctx, $args, $cond ) = @_;
    my $value = $args->{ 'value' };
    if (! $value ) {
        $value = $args->{ 'var' } || return '';
    }
    my $name = $args->{ 'name' } || return '';
    my $hash = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $hash ) eq 'HASH' ) {
        for my $key ( keys %$hash ) {
            if ( $hash->{ $key } eq $value ) {
                return $key;
                last;
            }
        }
    }
    return '';
}

sub _hdlr_array_join {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $glue  = $args->{ 'glue ' } || '';
    my $array = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $array ) eq 'ARRAY' ) {
        return join( $glue, $array );
    }
    return '';
}

sub _hdlr_array_rand {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $array = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $array ) eq 'ARRAY' ) {
        my $count = @$array; 
        my $num = int( rand( $count ) );
        return @$array[ $num ];
    }
}

sub _hdlr_split_var {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $glue = $args->{ 'glue' } || ',';
    my $var = $ctx->stash( 'vars' )->{ $name };
    my $set = $args->{ 'set' };
    if (! $var ) {
        $var = $args->{ var };
    }
    if ( $var ) {
        my @vars = split( /$glue/, $var );
        if ( $set ) {
            $ctx->stash( 'vars' )->{ $set } = \@vars;
        } else {
            $ctx->stash( 'vars' )->{ $name } = \@vars;
        }
    }
    return '';
}

sub _hdlr_array_shuffle {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $var = $ctx->stash( 'vars' )->{ $name };
    if (! $var ) {
        return '';
    }
    eval "require List::Util;";
    unless ( $@ ) {
        my @vars = List::Util::shuffle( @$var );
        $ctx->stash( 'vars' )->{ $name } = \@vars;
    }
    return '';
}

sub _hdlr_array_reverse {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $var = $ctx->stash( 'vars' )->{ $name };
    if (! $var ) {
        return '';
    }
    my @vars = reverse( @$var );
    $ctx->stash( 'vars' )->{ $name } = \@vars;
    return '';
}

sub _hdlr_array_unique {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $var = $ctx->stash( 'vars' )->{ $name };
    if (! $var ) {
        return '';
    }
    my @_var;
    for my $value ( @$var ) {
        if (! grep( /^$value$/, @_var ) ) {
            push( @_var, $value );
        }
    }
    $ctx->stash( 'vars' )->{ $name } = \@_var;
    return '';
}

sub _hdlr_set_published_entry_ids {
    my ( $ctx, $args, $cond ) = @_;
    my $entry_ids = $args->{ 'entry_ids' } || return '';
    if ( ( ref $entry_ids ) eq 'ARRAY' ) {
        my $entry_ids_published = $ctx->{__stash}{ entry_ids_published } || {};
        for my $id ( @$entry_ids ) {
            $entry_ids_published->{ $id } = 1;
        }
        $ctx->{ __stash }{ entry_ids_published } = $entry_ids_published;
    }
    return '';
}

sub _hdlr_get_vardump {
    my ( $ctx, $args, $cond ) = @_;
    my $vars = $ctx->{ __stash }{ vars } ||= {};
    my $dump;
    if ( my $name = $args->{ name } ) {
        $dump = "${name} => \n" . ( Dumper $vars->{ $name } );
    } else {
        $dump = Dumper $vars;
    }
    $dump = MT::Util::encode_html( $dump );
    $dump = '<pre><code style="overflow:auto">' . $dump . '</code></pre>';
    return $dump;
}

sub _hdlr_entries_entry_ids {
    my ( $ctx, $args, $cond ) = @_;
    my $terms = $ctx->{ terms };
    my $entry_ids = $args->{ entry_ids };
    if ( ( ref $entry_ids ) eq 'ARRAY' ) {
        my @ids = @$entry_ids;
        $terms->{ id } = \@ids;
    }
    return '';
}

sub _hdlr_delete_vars {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    if ( ( ref $name ) ne 'ARRAY' ) {
        if ( $name =~ m/\s/ ) {
            my @names = split( /\s{1,}/, $name );
            $name = \@names;
        } else {
            $name = [ $name ];
        }
    }
    for my $n ( @$name ) {
        delete( $ctx->stash( 'vars' )->{ $n } );
    }
}

sub _hdlr_append_var {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $var = $args->{ 'var' };
    $ctx->stash( 'vars' )->{ $name }->{ $var } = $ctx->stash( 'vars' )->{ $var };
    return '';
}

sub _hdlr_array_search {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $array = $ctx->stash( 'vars' )->{ $name } || return '';
    my $value = $args->{ 'value' };
    if (! $value ) {
        $value = $args->{ 'var' } || return '';
    }
    my $i = 0;
    for my $var ( @$array ) {
        if ( $var eq $value ) {
            return $i;
        }
        $i++;
    }
    return '';
}

sub _hdlr_array_sort {
    my ( $ctx, $args, $cond ) = @_;
    my $name = $args->{ 'name' } || return '';
    my $kind = $args->{ kind } || 'numeric';
    my $order = $args->{ order };
    $order = $args->{ sort_order } unless $order;
    if (! $order ) {
        $order = 'ascend';
    }
    my @vars;
    my $array = $ctx->stash( 'vars' )->{ $name };
    if ( ( ref $array ) eq 'ARRAY' ) {
        @vars = @$array;
        if ( ( $kind eq 'str' ) && ( $order eq 'ascend' ) ) {
            @vars = sort { $a cmp $b } @vars;
        } elsif ( ( $kind eq 'str' ) && ( $order eq 'descend' ) ) {
            @vars = sort { $b cmp $a } @vars;
        } elsif ( ( $kind eq 'numeric' ) && ( $order eq 'ascend' ) ) {
            @vars = sort { $a <=> $b } @vars;
        } elsif ( ( $kind eq 'numeric' ) && ( $order eq 'descend' ) ) {
            @vars = sort { $b <=> $a } @vars;
        }
        $array = \@vars;
    }
    $ctx->stash( 'vars' )->{ $name } = $array;
    return '';
}

sub _hdlr_reset_vars {
    my ( $ctx, $args, $cond ) = @_;
    $ctx->stash( '__get_hash_var_old_vars', $ctx->stash( 'vars' ) );
    $ctx->stash( 'vars', {} );
    return '';
}

sub _hdlr_save_vars {
    my ( $ctx, $args, $cond ) = @_;
    $ctx->stash( '__get_hash_var_old_vars', $ctx->stash( 'vars' ) );
    return '';
}

sub _hdlr_restore_vars {
    my ( $ctx, $args, $cond ) = @_;
    $ctx->stash( 'vars', $ctx->stash( '__get_hash_var_old_vars' ) );
    return '';
}

sub _hdlr_stash_to_vars {
    my ( $ctx, $args, $cond ) = @_;
    my $stash = $args->{ stash };
    my $object = $ctx->stash( $stash );
    return '' unless $object;
    my $install_properties;
    eval {
        $install_properties = $object->install_properties;
    };
    unless ( $@ ) {
        if ( ( ref $install_properties ) eq 'HASH' ) {
            my $values = $object->get_values;
            if ( my $meta = $object->meta ) {
                if ( ( ref $meta ) eq 'HASH' ) {
                    for my $field( keys %$meta ) {
                        my $field_name = $field;
                        $field_name =~ s/\./_/;
                        $values->{ $field_name } = $object->$field;
                    }
                }
            }
            for my $key ( keys %$values ) {
                $ctx->stash( 'vars' )->{ $stash . '_' . $key } = $values->{ $key };
            }
        }
    }
    return '';
}

sub _filter_json2vars {
    my ( $json, $name, $ctx ) = @_;
    my $array = MT::Util::from_json( $json );
    $ctx->stash( 'vars' )->{ $name } = $array;
    return '';
}

sub _filter_vars2json {
    my ( $array, $arg, $ctx ) = @_;
    return MT::Util::to_json( $array );
}

sub _filter_mtignore {
    my ( $text, $arg, $ctx ) = @_;
    if ( $arg ) {
        return '';
    }
    return $text;
}

sub _filter_note {
    my ( $text, $arg, $ctx ) = @_;
    return $text;
}

1;