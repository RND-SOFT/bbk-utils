# BBK::Utils

<div style="text-align:center" _render="для YARD чтоб внтури сделать markdown">

[![Gem Version](https://badge.fury.io/rb/bbk-utils.svg)](https://rubygems.org/gems/bbk-utils)
[![Gem](https://img.shields.io/gem/dt/bbk-utils.svg)](https://rubygems.org/gems/bbk-utils/versions)
[![YARD](https://lysander.rnds.pro/api/v1/badgen/YARD/doc/blue)](http://www.rubydoc.info/gems/bbk-utils)

[![Coverage](https://lysander.rnds.pro/api/v1/badges/bbkutils_coverage.svg)](https://lysander.rnds.pro/api/v1/badges/bbkutils_coverage.html)
[![Quality](https://lysander.rnds.pro/api/v1/badges/bbkutils_quality.svg)](https://lysander.rnds.pro/api/v1/badges/bbkutils_quality.html)
[![Outdated](https://lysander.rnds.pro/api/v1/badges/bbkutils_outdated.svg)](https://lysander.rnds.pro/api/v1/badges/bbkutils_outdated.html)
[![Vulnerabilities](https://lysander.rnds.pro/api/v1/badges/bbkutils_vulnerable.svg)](https://lysander.rnds.pro/api/v1/badges/bbkutils_vulnerable.html)

</div>

Common classes and helpers for BBK library stack.

## Installation

Adding to a gem:

```ruby
# my-cool-gem.gemspec

Gem::Specification.new do |spec|
  # ...
  spec.add_dependency "bbk-utils", "~> 1.0.0"
  # ...
end
```

Or adding to your project:

```ruby
# Gemfile

gem "bbk-utils", "~> 1.0.0"
```

## Features

### bbkdocs

Создать `bin/bbkdocs`:

```ruby
#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'bbk/utils/cli'

BBK::Utils::Cli::Docs.new(ARGV).run
```

Добавить в `Rakefile`:

```ruby
# Загружаем таски из BBK::Utils. В частности генерацию документации
BBK::Utils.load_tasks
```


## Contributing

See the file [CONTRIBUTING.md](./CONTRIBUTING.md)

## License

See the file [LICENSE](./LICENSE)

