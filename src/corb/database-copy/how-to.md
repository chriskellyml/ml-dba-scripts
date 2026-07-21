# Database copy

Copy all documents from one database to another database in the same MarkLogic
cluster:

```shell
make copy-database FROM=foo DTO=bar LIMIT=1000000 THREADS=4 BATCH=30 \
  HOST=localhost PORT=8000 USER=admin PASS=admin
```

The script creates the destination database and empty forests when the database
does not exist. An existing destination is used unchanged. It counts source
documents, calculates the number of pages, and runs the Gradle CoRB task once
for each page.

The processor preserves each document's URI, content, collections, permissions,
quality, properties, and metadata. `PORT` must identify an App Server that
accepts REST evaluation and XCC connections, and the source database must have
the URI lexicon enabled.
