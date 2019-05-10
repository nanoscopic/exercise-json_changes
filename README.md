# exercise-json_changes
### Project Requirements

Here are the basic parameters for this exercise:

1.  This input JSON file consists of a set of users, songs, and playlists that are part of a music service: [mixtape.json](https://gist.githubusercontent.com/jmodjeska/0679cf6cd670f76f07f1874ce00daaeb/raw/a4ac53fa86452ac26d706df2e851fb7d02697b4b/mixtape-data.json).
2.  Your application ingests `mixtape.json`.
3.  Your application ingests a changes file, which can take whatever form you like (we use `changes.json` in our example, but you’re free to make it text, YAML, CSV, or whatever). The changes file should include multiple changes in one file.
4.  Your application outputs `output.json` in the same structure as `mixtape.json`, with the changes applied. The types of changes you need to support are ennumerated below and the application should process all changes in one pass.
5.  Your solution includes a README that explains how to use your application and a way to validate its output.
6.  Your README describes what changes you would need to make in order to scale this application to handle very large input files and/or very large changes files. Just describe the changes — you don’t actually need to implement a scaled-up version of the application.
7.  Don’t worry about creating a UI, DB, server, or deployment.
8.  Your code should be executable on Mac or Linux.

The types of changes your application needs to support are:

1.  Add an existing song to an existing playlist.
2.  Add a new playlist for an existing user; the playlist should contain at least one existing song.
3.  Remove an existing playlist.
### Dependencies
The script using a few Perl modules. Install these before running it:
1. cpan install JSON::XS
2. cpan install File::Slurp

If you don't have perl and cpan on your system yet you'll need to install those also.
### Usage
	perl ./jsonmod.pl

### Testing / Output Validation
Go look at the output and verify it makes sense compared to your changes. :D ( TODO: Make a test script to do this automatically )

### Scaling
In order to scale this:
1. Don't use a JSON file as the storage mechanism
2. Use a relational database to store everything. The schema given here is very simple and lends itself well to that. MariaDB and/or Postgres would work great here.
3. If there are a large number of users and/or millions of songs, use a sharded database pattern. Basically just segment songs by subsections of artist name and segment users by id. Then use the database containing the proper segment. No need here even to use a "NoSQL" database.

### Scaling with NoSQL
Because this is obviously being "asked for" by way of the silly use of JSON for data, one solution would be to use a NoSQL datastore. Those are essentially just a key/value store that is scaling by sharding on the key.

Personally I think for the example type of data given NoSQL is a bad idea, but I'll explain it briefly here.

Essentially, do what I said in "scaling" but just setup the keys to be the things that are desired to be shared, and then let your NoSQL DB system scale to the number of nodes you desire for performance.

There are some slight benefits to this in that sharding is easier, and potentially it is easier to store multiple versions of documents ( versioning song schema for example ) but I still don't think it would justify the usage.


