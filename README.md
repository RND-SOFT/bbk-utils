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

Набор общих классов и вспомогательных модулей для стека библиотек BBK. / Common classes and helpers for BBK library stack.


## Установка / Installation

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
## Возможности / Features

### EnvHelper — сборка URL подключений / URL Building Helper

Нормализует переменные окружения: собирает URL из отдельных компонентов и раскладывает обратно. Три уровня приоритетов: ENV-переменная > компонент из базового URL > значение по умолчанию.

Normalizes environment variables: builds URLs from individual components and decomposes back. Three-level priorities: env var > component from base URL > default.

```ruby
# Базы данных / Databases — prepare_database_envs
env = { 'DATABASE_URL' => 'postgres://user:pass@host:5432/db', 'DATABASE_HOST' => 'newhost' }
BBK::Utils::EnvHelper.prepare_database_envs(env)
# => env['DATABASE_URL'] = 'postgres://user:pass@newhost:5432/db'

# Очереди сообщений / Message Queues — prepare_mq_envs
env = { 'MQ_HOST' => 'mq1;mq2;mq3', 'MQ_USER' => 'guest' }
BBK::Utils::EnvHelper.prepare_mq_envs(env)
# => env['MQ_URL'] = 'amqps://guest@mq1:5671/;amqps://guest@mq2:5671/;amqps://guest@mq3:5671/'

# Jaeger Tracing — prepare_jaeger_envs
BBK::Utils::EnvHelper.prepare_jaeger_envs(ENV)
```

### Config — декларативная работа с переменными окружения / Declarative ENV Management

Декларативное описание, валидация и чтение переменных окружения с поддержкой типов, значений по умолчанию, подконфигураций и маскирования секретов.

Declarative description, validation, and reading of environment variables with type casting, defaults, subconfigurations, and secret masking.

```ruby
require 'bbk/utils'

BBK::Utils::Config.instance.tap do |cfg|
  cfg.require('API_KEY', desc: 'API key', secure: true)
  cfg.optional('LOG_LEVEL', default: 'info', desc: 'Logging level')
  cfg.optional('TIMEOUT', default: 30, type: method(:Integer), desc: 'Timeout in seconds')
  cfg.optional('DEBUG_MODE', default: false, bool: true, desc: 'Enable debug mode')
  cfg.optional('CLEAN_INTERVAL', default: '3month', type: method(:duration_parser))

  cfg.map('SSL_CERT', '/etc/ssl/cert.pem', desc: 'SSL certificate')

  cfg.subconfig(prefix: 'REDIS') do |redis|
    redis.optional('URL', default: 'redis://redis:6379/0', desc: 'Redis URL')
    redis.optional('POOL_SIZE', default: 5, type: method(:Integer), desc: 'Pool size')
  end
end

# Важно: сначала EnvHelper, потом Config
# Important: EnvHelper first, then Config
BBK::Utils::EnvHelper.prepare_database_envs(ENV)
BBK::Utils::EnvHelper.prepare_mq_envs(ENV)
BBK::Utils::Config.run!(ENV)

# Доступ к значениям / Accessing values
BBK::Utils::Config['LOG_LEVEL']   # => "info"
BBK::Utils::Config['REDIS_URL']   # => "redis://redis:6379/0"
puts BBK::Utils::Config.to_s
```

#### Префиксы и альтернативные имена / Prefixes & Alternative Names

```ruby
config = BBK::Utils::Config.instance(prefix: 'MYAPP')
config.optional('PORT', default: 3000)  # читает MYAPP_PORT

cfg.require('DB_URL', key: 'DATABASE_URL', desc: 'Database URL')  # ищет DATABASE_URL, доступен как DB_URL
```

#### Приведение булевых значений / Boolean Casting

`false, 0, '0', 'f', 'false', 'off'` (и их вариации) → `false`. Всё остальное → `true`. Пустая строка и `nil` → `nil`.

`false, 0, '0', 'f', 'false', 'off'` (and variations) → `false`. Everything else → `true`. Empty string and `nil` → `nil`.

### bbkdocs — генерация документации / Documentation Generator

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

