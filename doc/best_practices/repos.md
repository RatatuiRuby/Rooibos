<!--
  SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
  SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Repos and Data Flow

After reading this guide, you will know:

- What a Repo is and why it exists
- How to structure read repos as Record, Fetched, and Fetch
- How to structure mutation repos as a verb/past-tense pair
- How to wire repos into fragments using existing Router declarations
- How to organize repo files by domain module

---

## Context

You've built fragments with Models, Views, and Updates. Your app works. Now you need data from the outside world: a remote API, a database, a file system. You also need to change things: delete an entry, toggle a setting, signal a process.

Both reads and mutations share the same challenge: they cross a boundary between your app and the outside world.

## Problem

Without structure, boundary-crossing code scatters across your codebase. The data shape lands in one file. The command lands in another. The message lands somewhere else. A new developer traces three files to understand one data source.

## Solution

Group each operation into one file. Call it a **Repo**. Repos that operate on the same external data source share a module.

Repos come in two flavors:

Read repos
: Fetch data and deliver results. The verb is always **Fetch**.

Mutation repos
: Change the outside world and report what happened. The verb describes the action.

Both follow the same grammar: a **[command](../essentials/commands.md)** (imperative verb) and a **[message](../essentials/messages.md)** (past tense of that verb). Read repos add a **Record** for the data shape.

---

## Read Repos

A read repo is a module containing three classes:

Record
: The data shape. What a single item looks like. Immutable, defined with `Data.define`.

Fetched
: The message that delivers results. Includes [`Rooibos::Message::Predicates`](../../lib/rooibos/message.rb).

Fetch
: The command that performs the work. Includes [`Rooibos::Command::Custom`](../../lib/rooibos/command/custom.rb).

```ruby
module RemoteFiles
  class Record < Data.define(:name, :path, :size_bytes, :modified_at, :kind, :owner)
    def directory? = kind == :directory
    def formatted_size
      return '—' if directory?

      if size_bytes < 1024
        "#{size_bytes} B"
      elsif size_bytes < 1_048_576
        "#{(size_bytes / 1024.0).to_i} KB"
      else
        "#{(size_bytes / 1_048_576.0).round(1)} MB"
      end
    end
  end

  class Fetched < Data.define(:entries, :total_size)
    include Rooibos::Message::Predicates
  end

  class Fetch < Data.define(:path)
    include Rooibos::Command::Custom

    def call(out, _token)
      listing = RemoteFS.list(path)
      entries = listing.map { |f| Record.new(name: f.name, path: f.path, ...) }
      out.put(Ractor.make_shareable(Fetched.new(entries:, total_size: listing.total_size)))
    end
  end
end
```

Fetch doesn't have to be a custom command. If your data comes from a REST API, use a built-in command instead:

```ruby
module RemoteFiles
  Fetch = Rooibos::Command.http(:get, "https://api.example.com/files", :remote_files,
                                 parser: method(:parse_listing).freeze)

  def self.parse_listing(body, _headers, _status)
    parsed = JSON.parse(body)
    entries = parsed['files'].map { |f| Record.new(name: f['name'], path: f['path'], ...) }
    Ractor.make_shareable(Fetched.new(entries:, total_size: parsed['total_size']))
  end
end
```

The triplet structure stays the same. Only the Fetch implementation changes.

One module. One file. Open the file and you understand the entire data source: what it returns, what the result looks like, how to fetch it.

---

## Mutation Repos

A mutation repo is a module containing two classes:

[Verb]
: The command that performs the mutation. Includes [`Rooibos::Command::Custom`](../../lib/rooibos/command/custom.rb).

[Verb]ed / [Verb]d
: The message that reports what happened. Includes [`Rooibos::Message::Predicates`](../../lib/rooibos/message.rb).

The naming convention: the message is the past tense of the command. `Delete` → `Deleted`. `Mount` → `Mounted`. `ChangeOwner` → `OwnerChanged`.

```ruby
module RemoteFiles
  class Deleted < Data.define(:succeeded_paths)
    include Rooibos::Message::Predicates
  end

  class Delete < Data.define(:paths)
    include Rooibos::Command::Custom

    def call(out, _token)
      succeeded_paths = []
      paths.each do |path|
        RemoteFS.delete(path)
        succeeded_paths << path
      rescue => e
        break
      end
      out.put(Ractor.make_shareable(Deleted.new(succeeded_paths:)))
    end
  end
end
```

Mutation repos don't define a Record. They change the outside world and report what happened. Include enough information in the message for the message receiver to react: which items changed, whether the operation succeeded, what the new state is.

### Multiple Operations on One Domain

A single domain module can have both reads and mutations. Each operation lives in its own file:

```ruby
# repos/remote_files/fetch.rb   — RemoteFiles::Record, ::Fetched, ::Fetch
# repos/remote_files/delete.rb  — RemoteFiles::Delete, ::Deleted
# repos/remote_files/rename.rb  — RemoteFiles::Rename, ::Renamed
# repos/remote_drives/fetch.rb  — RemoteDrives::Record, ::Fetched, ::Fetch
# repos/remote_drives/mount.rb  — RemoteDrives::Mount, ::Mounted
```

Ruby's open modules let each file contribute to the same `RemoteFiles` and `RemoteDrives` modules. The module name is the **noun** (what you're operating on). The class names are the **verbs** (what you do to it).

The pattern scales to any external system: REST APIs, databases, file systems, hardware, RPC services, and more.

| Operation | Command | Message |
|-----------|---------|---------|
| List files | `RemoteFiles::Fetch` | `RemoteFiles::Fetched` |
| Remove a file | `RemoteFiles::Delete` | `RemoteFiles::Deleted` |
| Attach a drive | `RemoteDrives::Mount` | `RemoteDrives::Mounted` |

---

## Domain Methods on Records

Records are immutable data, but they can have methods. Add domain logic directly:

```ruby
class Record < Data.define(:name, :path, :size_bytes, :modified_at, :kind, :owner)
  def directory? = kind == :directory
  def hidden? = name.start_with?('.')
  def extension = File.extname(name)
  def formatted_size
    return '—' if directory?

    if size_bytes < 1024
      "#{size_bytes} B"
    elsif size_bytes < 1_048_576
      "#{(size_bytes / 1024.0).to_i} KB"
    else
      "#{(size_bytes / 1_048_576.0).round(1)} MB"
    end
  end
end
```

The Record knows how to format and compute its own values. Views call `entry.formatted_size` instead of reimplementing the logic.

## Records vs. Models

Both use `Data.define`. Both are immutable. The difference is what they represent.

Records
: Facts about the outside world. A file's size. A server's hostname. You receive a Record from a Fetch command. You never modify it; instead, you fetch a fresh snapshot.

Models
: Your application's internal state. Which tab is active. Whether data is loading. What the user selected. You evolve a Model with `with` in your Update function.

```ruby
# Record — external fact, read-only
RemoteFiles::Record.new(name: "notes.txt", size_bytes: 1024, ...)
entry.formatted_size  # "1 KB"

# Model — internal state, evolves over time
model = Model.new(loading: true, entries: [], ...)
model.with(loading: false, entries: fetched_entries)
```

A Record answers "what does the world look like?" A Model answers "what is my app doing right now?" Records are defined in repos. Models are defined in fragments. Your Model stores Record instances as properties (`Model.new(entries: [Record.new(...), ...])`), but the two types serve different purposes.

### Empty Records

Repos that serve as initial state define an `EMPTY` constant on the Record class:

```ruby
class Record < Data.define(:hostname, :os, :disk_total, :disk_free, :uptime_days)
  EMPTY = Ractor.make_shareable(
    new(hostname: 'N/A', os: 'N/A', disk_total: 'N/A',
        disk_free: 'N/A', uptime_days: 'N/A')
  )
end
```

Use `ServerInfo::Record::EMPTY` for initial model state. This keeps skeleton and loading values close to the data shape that defines them.

## The Naming Convention

Name your Fetched fields to match your Model fields:

```ruby
# Repo
class Fetched < Data.define(:entries, :total_size)

# Fragment model
Model = Data.define(:loading, :table, :entries, :total_size)
```

When names match, the wiring in your Update is a simple splat. See below.

---

## Wiring Repos into Fragments

Repos use existing Rooibos primitives. No special framework support is needed. The wiring has two parts for reads and one part for mutations.

### Reads: Init Fetches, Update Handles

Return the Fetch command from Init alongside your initial model:

```ruby
Init = -> {
  [Ractor.make_shareable(Model.new(loading: true, entries: [], total_size: 0)),
    RemoteFiles::Fetch.new(path: '/')]
}
```

The runtime executes the command. When the result arrives, your Update handles it:

```ruby
receive_instances_of RemoteFiles::Fetched, ->(message, model) {
  model.with(loading: false, **message.to_h)
}
```

When your Fetched fields match your Model fields, `**message.to_h` maps them automatically. For complex cases, write the mapping explicitly:

```ruby
receive_instances_of RemoteFiles::Fetched, ->(message, model) {
  new_table = model.table.with(row_ids: message.entries.map(&:path))
  model.with(loading: false,
             table: new_table,
             entries: message.entries,
             total_size: message.total_size)
}
```

### Mutations: Issuing Commands

Mutations are triggered by user actions, not Init. Issue the command from a handler:

```ruby
receive_events :d, lambda { |_, model|
  [model, RemoteFiles::Delete.new(paths: [model.selected_path])]
}
```

Handle the result with any [Router DSL family](../scaling_up/message_routing.md#the-three-families) — `receive`, `observe`, `forward`, or a combination. A common pattern is to re-fetch data after a mutation and deselect affected rows:

```ruby
observe_instances_of RemoteFiles::Deleted, lambda { |_, model|
  RemoteFiles::Fetch.new(path: model.current_path)
}
forward_instances_of RemoteFiles::Deleted, to: :list, as: :deselect
```

Here `observe` triggers a refresh (the data changed, fetch it again) and `forward` tells the list to deselect the affected rows. Both run because `observe` doesn't consume the message.

### Refreshing: You Decide When

The framework doesn't know when to refresh data. That decision belongs to your application. Any fragment can issue Fetch commands: on a timer tick, after a mutation, on navigation, or when the user explicitly requests a refresh:

```ruby
# Re-fetch the active screen's data on a timer tick
receive_instances_of TimerTick, ->(message, model) {
  RemoteFiles::Fetch.new(path: model.current_path)
}
```

The result flows back through your Router-generated Update to the fragment's `receive_instances_of` handler.

### Complete Fragment

```ruby
module Files
  include Rooibos::Router

  Model = Data.define(:loading, :entries, :total_size)

  Init = -> {
    model = Model.new(loading: true, entries: [], total_size: 0)
    [Ractor.make_shareable(model), RemoteFiles::Fetch.new(path: '/')]
  }

  View = ->(model, tui) {
    rows = model.entries.map do |entry|
      tui.table_row(cells: [entry.name, entry.formatted_size, entry.modified_at.to_s])
    end
    tui.table(header: ['Name', 'Size', 'Modified'], rows: rows)
  }

  receive_instances_of RemoteFiles::Fetched, ->(message, model) {
    model.with(loading: false, **message.to_h)
  }

  Update = from_router
end
```

---

## File Organization

Repos live in a `repos/` directory. Each domain module gets its own subdirectory. Each operation gets its own file:

```
app/
  repos/
    remote_files/
      fetch.rb              # RemoteFiles::Record, ::Fetched, ::Fetch
      delete.rb             # RemoteFiles::Delete, ::Deleted
    volumes/
      fetch.rb              # Volumes::Record, ::Fetched, ::Fetch
      mount.rb              # Volumes::Mount, ::Mounted
    server_info/
      fetch.rb              # ServerInfo::Record, ::Fetched, ::Fetch
  fragments/
    files.rb                # receive_instances_of RemoteFiles::Fetched
    volumes.rb              # reopens Volumes module with fragment code
    dashboard.rb            # handles ServerInfo::Fetched
  root.rb
```

When a fragment and a repo share a name (like Volumes), Ruby's open modules let both files contribute to the same module. The repo files define Record, Fetched, Fetch, and mutation pairs. The fragment file defines Model, Init, View, and Update.

---

## See Also

- [Router-Based Composition Patterns](../scaling_up/message_routing.md) — The Router DSL used to wire repos
- [Custom Commands](../scaling_up/custom_commands.md) — How `Fetch` commands work under the hood
- [Rooibos UI](../scaling_up/rooibos_ui.md) — Higher-level layout patterns for tabbed interfaces
