#!/usr/bin/perl -w
use strict;
use JSON::XS;
use File::Slurp qw/read_file/;
use Data::Dumper;

my $rawJson = read_file( 'mixtape-data.json' );
my $json = decode_json( $rawJson );

my $coder = JSON::XS->new->utf8->pretty->canonical(1);

my $rawChanges = read_file( 'changes.json' );
my $changes = decode_json( $rawChanges );

for my $change ( @$changes ) {
    my $type = $change->{type};
    # Example:
    # {
    #   "type": "add",
    #   "autoId": 1,
    #   "path": "users",
    #   "node": {
    #   }
    # }
    if( $type eq 'add' ) {
        my $path = $change->{path};
        my $autoId = $change->{autoId};
        my $pos = navigate( $json, $path );
        
        my $newId = undef;
        if( $autoId ) {
            my $maxId = 0;
            for my $node ( @$pos ) {
                my $nodeId = $node->{id};
                if( $nodeId > $maxId ) {
                    $maxId = $nodeId;
                }
            }
            $newId = $maxId + 1;
        }
        my $node = $change->{node};
        if( $newId ) {
            $node->{id} = "$newId";
        }
        push( @$pos, $node );
    }
    
    # Example
    # {
    #   "type": "delete",
    #   "path": "songs",
    #   "select": "id=40"
    # }
    if( $type eq 'delete' ) {
        my $path = $change->{path};
        my $selects = $change->{select};
        
        my @parts = split( ',', $selects );
        my $selectArr = [];
        
        for my $select ( @parts ) {
            print "Select: $select\n";
            if( $select =~ m/(.+)=(.+)/ ) {
                my $attr = $1;
                my $val = $2;
                push( @$selectArr, { attr => $attr, val => $val } );
            }
            else {
                die "Invalid select expression $select";
            }
        }
        del( $json, $path, $selectArr );
    }
}

my $outJson = $coder->encode( $json );
print $outJson;

sub del {
    my ( $root, $path, $select ) = @_;
    print "Path=$path\n";
    print "Selecting with:\n";
    print Dumper( $select );
    my $pos = navigate( $root, $path );
    
    #print Dumper( $pos );
    my $i = find( $pos, $select );
        
    if( defined $i ) {
        #print "Found at $i, deleting\n";
        splice @$pos, $i, 1;
    }
}

sub find {
    my ( $arr, $selects ) = @_;
    my $i = 0;
    OUTER: for my $node ( @$arr ) {
        #print "Checking node:\n";
        #print Dumper( $node );
        for my $select ( @$selects ) {
            my $attr = $select->{attr};
            my $val = $select->{val};
            if( $node->{$attr} ne $val ) {
                $i++;
                next OUTER;
            }
        }
        return $i;
    }
    return undef;
}

sub navigate {
    my ( $top, $path ) = @_;
    my @parts = split( '\.', $path );
    
    print "Navigating\n";
    my $curpos = $top;
    for my $part ( @parts ) {
        print "  Part=$part\n";
        if( $part =~ m/^[0-9]+$/ ) {
            $curpos = $curpos->[ $part ];
            next;
        }
        $curpos = $curpos->{ $part };
    }
    return $curpos;
}
