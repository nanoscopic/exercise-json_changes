#!/usr/bin/perl -w
use strict;
use JSON::XS;
use File::Slurp qw/read_file write_file/;
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
        add( $json, $change );
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
            #print "Select: $select\n";
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
    
    # Example:
    # {
    #   "type": "addSongToPlaylist",
    #   "playlistId": 1, 
    #   "userId": 2,
    #   "songId": 3
    # }
    if( $type eq 'addSongToPlaylist' ) {
        my $playlistId = $change->{playlistId};
        my $userId = $change->{userId};
        my $songId = $change->{songId};
        
        my $pos = navigate( $json, "playlists" );
        my $i = find( $pos, [ { attr => 'id', val => $playlistId } ] );
        if( defined $i ) {
            my $node = $pos->[ $i ];
            my $foundUserId = $node->{user_id};
            if( $foundUserId ne $userId ) {
                die "UserId does not match - $foundUserId != $userId";
            }
            my $songIds = $node->{song_ids};
            
            my $found = 0;
            for my $oneId ( @$songIds ) {
                if( $oneId eq $songId ) {
                    $found = 1;
                    last;
                }
            }
            if( $found ) {
                die "Song id already present in playlist";
            }
            
            # This is inefficient; assuming it is already sorted every time we can just scan to insertion point
            # and add without doing a sort. Doing a sort here as this is just a coding exercise...
            # Also note that the sample playlist song ids do not have all the song ids sorted... which they should...
            push( @$songIds, $songId );
            @$songIds = sort { $a <=> $b } @$songIds;
        }
    }
    
    # Example:
    # {
    #   "type": "delPlaylist",
    #   "playlistId": 1, 
    #   "userId": 2,
    # }
    if( $type eq 'delPlaylist' ) {
        my $playlistId = $change->{playlistId};
        my $userId = $change->{userId};
        
        my $pos = navigate( $json, "playlists" );
        my $i = find( $pos, [ { attr => 'id', val => $playlistId } ] );
        if( defined $i ) {
            my $node = $pos->[ $i ];
            my $foundUserId = $node->{user_id};
            if( $foundUserId ne $userId ) {
                die "UserId does not match - $foundUserId != $userId";
            }
            splice( @$pos, $i, 1 );
        }
    }
    
    # Example:
    # {
    #   "type": "addPlaylist",
    #   "userId": 10,
    #   "songIds": [20,30]
    # }
    if( $type eq 'addPlaylist' ) {
        my $userId = $change->{userId};
        # Note that user id is not checked to be sure it is valid here
        my $songIds = $change->{songIds};
        
        if( !$songIds || !@$songIds ) {
            # requirement of exercise says that playlists must contain at least one song...
            # why that is? who knows. Maybe to see if people pay attention to the req?
            die "Some songs must be specified when adding a playlist";
        }
        
        my @songIdsAsStrings;
        # stringify song ids since they appear that way in example data
        # I'm also sorting them numerically for sanity
        for my $songId ( sort { $a <=> $b } @$songIds ) {
            push( @songIdsAsStrings, "$songId" );
        }
        
        
        # Note that song ids are not checked to ensure that are valid here
        add( $json, {
            path => 'playlists',
            autoId => 1,
            node => {
                user_id => "$userId",
                song_ids => \@songIdsAsStrings
            }
        } );
    }
    
    # Example:
    # {
    #   "type": "addSong",
    #   "song": {
    #     "artist" : "blah",
    #     "title" : "blahblah2"
    #   }
    # }
    if( $type eq 'addSong' ) {
        # Note that no sanity checking is done for the contents of song here; it is just dumped in blindly.
        # Bad practice really. Everything should be checked against a schema.
        # Additionally we could end up adding a duplicate here; am specifically not checking here for
        # duplicate addition but it could easily be done by checking first with the 'find' function.
        add( $json, {
            path => 'songs',
            autoId => 1,
            node => $change->{song}
        } );
    }
}

my $outJson = $coder->encode( $json );
write_file( "output.json", $outJson );

sub add {
    my ( $json, $change ) = @_;
    
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

sub del {
    my ( $root, $path, $select ) = @_;
    #print "Path=$path\n";
    #print "Selecting with:\n";
    #print Dumper( $select );
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
    
    #print "Navigating\n";
    my $curpos = $top;
    for my $part ( @parts ) {
        #print "  Part=$part\n";
        if( $part =~ m/^[0-9]+$/ ) {
            $curpos = $curpos->[ $part ];
            next;
        }
        $curpos = $curpos->{ $part };
    }
    return $curpos;
}
