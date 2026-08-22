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

Набор общих классов и вспомогательных модулей для стека библиотек BBK.

Common classes and helpers for BBK library stack.

---

## Установка / Installation

Добавление в gem / Adding to a gem:

```ruby
# my-cool-gem.gemspec

Gem::Specification.new do |spec|
  # ...
  spec.add_dependency "bbk-utils", "~> 1.0.0"
  # ...
end
```

Или добавление в проект / Or adding to your project:

```ruby
# Gemfile

gem "bbk-utils", "~> 1.0.0"
```

---

## Возможности / Features

### EnvHelper — Сборка URL подключений / URL Building Helper

Модуль `BBK::Utils::EnvHelper` предоставляет утилиты для нормализации и сборки переменных окружения при подключении к внешним сервисам (базы данных, очереди сообщений, трейсинг).

---

The `BBK::Utils::EnvHelper` module provides utilities for normalizing and building environment variables for connecting to external services (databases, message queues, tracing).

#### Основные возможности / Key Features

- **Интеллектуальная сборка URL**: собирает строки подключения из отдельных переменных окружения или переопределяет компоненты существующего URL
- **Трехуровневые приоритеты**: переменная окружения > компонент из базового URL > значение по умолчанию
- **Двусторонняя синхронизация**: после сборки URL раскладывает его обратно в индивидуальные переменные
- **Поддержка кластеров**: для MQ поддерживает множественные хосты через разделители `;` или `|`

---

- **Intelligent URL building**: constructs connection strings from individual environment variables or overrides components of existing URLs
- **Three-level priorities**: environment variable > component from base URL > default value
- **Bidirectional synchronization**: after building URL, decomposes it back into individual variables
- **Cluster support**: for MQ supports multiple hosts via `;` or `|` separators

#### Базы данных / Databases (`prepare_database_envs`)

```ruby
env = {
  'DATABASE_URL' => 'postgres://user:pass@host:5432/db',
  'DATABASE_HOST' => 'newhost'  # переопределяет хост из URL / overrides host from URL
}
BBK::Utils::EnvHelper.prepare_database_envs(env)
# => env['DATABASE_URL'] = 'postgres://user:pass@newhost:5432/db'
# => env['DATABASE_HOST'] = 'newhost'
# => env['DATABASE_PORT'] = '5432'
# => и т.д. / etc.
```

Поддерживаемые переменные (с префиксом `DATABASE`) / Supported variables (with `DATABASE` prefix):

- `DATABASE_URL` - базовый URL (опционально) / base URL (optional)
- `DATABASE_ADAPTER` - адаптер (default: `postgresql`) / adapter (default: `postgresql`)
- `DATABASE_HOST` - хост (default: `db`) / host (default: `db`)
- `DATABASE_PORT` - порт (default: `5432`) / port (default: `5432`)
- `DATABASE_USER` - пользователь (default: `postgres`) / user (default: `postgres`)
- `DATABASE_PASS` - пароль / password
- `DATABASE_NAME` - имя БД / database name
- `DATABASE_POOL` - размер пула соединений (используется только если в URL есть query-строка) / connection pool size (used only if the URL contains a query string)

#### Очереди сообщений / Message Queues (`prepare_mq_envs`)

```ruby
env = { 'MQ_HOST' => 'mq1;mq2;mq3', 'MQ_USER' => 'guest' }
BBK::Utils::EnvHelper.prepare_mq_envs(env)
# => env['MQ_URL'] = 'amqps://guest@mq1:5671/;amqps://guest@mq2:5671/;amqps://guest@mq3:5671/'
```

#### Jaeger Tracing (`prepare_jaeger_envs`)

```ruby
env = { 'JAEGER_HOST' => 'jaeger-agent' }
BBK::Utils::EnvHelper.prepare_jaeger_envs(env)
# => env['JAEGER_URL'] = 'udp://jaeger-agent:6831'
```

#### Пример использования / Usage Example

```ruby
# Нормализуем переменные окружения для базы данных (мутирует ENV in-place)
# Normalize database environment variables (mutates ENV in-place)
BBK::Utils::EnvHelper.prepare_database_envs(ENV)

# Теперь в ENV доступны согласованные переменные:
# Now ENV contains consistent variables:
#   ENV['DATABASE_URL']  => собранный URL / assembled URL
#   ENV['DATABASE_HOST'] => хост / host
#   ENV['DATABASE_PORT'] => порт / port
#   ENV['DATABASE_NAME'] => имя БД / database name
#   ... и т.д. / etc.

database_url = ENV['DATABASE_URL']
```

### Config — Декларативная работа с переменными окружения / Declarative Environment Variables Management

Класс `BBK::Utils::Config` предоставляет декларативный способ описания, валидации и чтения переменных окружения с поддержкой типов, значений по умолчанию, подконфигураций и маскирования секретов.

---

The `BBK::Utils::Config` class provides a declarative way to describe, validate, and read environment variables with support for types, default values, subconfigurations, and secret masking.

#### Основные возможности / Key Features

- **Декларативное описание** — переменные регистрируются через `optional` / `require` с указанием типа, дефолта и описания
- **Автоматическая валидация** — отсутствие обязательных переменных вызывает ошибку на старте
- **Приведение типов** — поддержка булевых значений (`bool: true`), кастомных парсеров (`type: method(:parser)`) и произвольных классов
- **Маскирование секретов** — флаг `secure: true` скрывает значения в логах как `[FILTERED]`
- **Подконфигурации** — группировка переменных с общим префиксом через `subconfig`
- **Читаемый вывод** — методы `to_s`, `to_json`, `to_yaml` для диагностики конфигурации
- **Приведение булевых значений** — поддержка форматов `0/1`, `true/false`, `on/off`, `f/t` через `BooleanCaster`

---

- **Declarative description** — variables are registered via `optional` / `require` with type, default, and description
- **Automatic validation** — missing required variables raise an error at startup
- **Type casting** — support for booleans (`bool: true`), custom parsers (`type: method(:parser)`), and arbitrary classes
- **Secret masking** — `secure: true` flag hides values in logs as `[FILTERED]`
- **Subconfigurations** — group variables with common prefix via `subconfig`
- **Readable output** — `to_s`, `to_json`, `to_yaml` methods for configuration diagnostics
- **Boolean casting** — supports formats `0/1`, `true/false`, `on/off`, `f/t` via `BooleanCaster`


#### Файловые конфигурации / File mappings (`map`)

Иногда необходимо передать содержимое переменной окружения в файл (например, сертификат или ключ). Для этого используйте метод `map`:

```ruby
BBK::Utils::Config.instance.tap do |cfg|
  cfg.map('SSL_CERT', '/etc/ssl/cert.pem', desc: 'SSL-сертификат')
end
BBK::Utils::Config.run!(ENV)

# После run! значение ENV['SSL_CERT'] будет записано в файл,
# а Config['SSL_CERT'] вернёт путь к файлу.
# Прочитать содержимое можно через Config.content('SSL_CERT')
```

#### Префиксы / Prefixes

Можно задать глобальный префикс для всех переменных:

```ruby
config = BBK::Utils::Config.instance(prefix: 'MYAPP')
config.optional('PORT', default: 3000)
config.run!(ENV)
# читает MYAPP_PORT
```

Префиксы также используются в подконфигурациях: если у родителя префикс `APP`, а у подконфигурации `DB`, переменная `HOST` будет читаться как `APP_DB_HOST`.

#### Альтернативные имена переменных / Alternative variable names

Параметр `key` позволяет связать логическое имя конфигурационной переменной с другим именем в ENV. Это удобно, когда в разных сервисах одна и та же переменная может называться по-разному.

```ruby
BBK::Utils::Config.instance.tap do |cfg|
  # Будет искать DATABASE_URL в ENV, но доступ через Config['DB_URL']
  cfg.require('DB_URL', key: 'DATABASE_URL', desc: 'Database connection string')
end
BBK::Utils::Config.run!(ENV)

# Доступ к значению по логическому имени
database_url = BBK::Utils::Config['DB_URL']
# => значение из ENV['DATABASE_URL']
```

#### Приведение булевых значений / Boolean Casting

`BooleanCaster` распознаёт следующие значения как `false`:

`BooleanCaster` recognizes the following values as `false`:

```ruby
false, 0, '0', :"0", 'f', :f, 'F', :F, 
'false', 'FALSE', :FALSE, 'off', :off, 'OFF', :OFF
```

Всё остальное (кроме `nil` и пустой строки) трактуется как `true`.

Anything else (except `nil` and empty string) is treated as `true`.

```ruby
BBK::Utils::Config.parse_bool_value('false')  # => false
BBK::Utils::Config.parse_bool_value('0')      # => false
BBK::Utils::Config.parse_bool_value('yes')    # => true
BBK::Utils::Config.parse_bool_value('')       # => nil
```

#### Интеграция с EnvHelper / Integration with EnvHelper

**Важно соблюдать порядок вызовов**: сначала `EnvHelper` нормализует `ENV` (собирает URL из компонентов), затем `Config#run!` читает уже готовые значения.

**The call order is important**: first `EnvHelper` normalizes `ENV` (builds URL from components), then `Config#run!` reads the ready values.

```ruby
# 1. Нормализация / Normalization
BBK::Utils::EnvHelper.prepare_database_envs(ENV)
BBK::Utils::EnvHelper.prepare_mq_envs(ENV)

# 2. Чтение и валидация / Reading and validation
BBK::Utils::Config.run!(ENV)
```

Если поменять порядок, переменные могут быть прочитаны до нормализации (например, `DATABASE_URL` будет пустым, хотя `DATABASE_HOST` задан).

If the order is reversed, variables may be read before normalization (e.g., `DATABASE_URL` will be empty even though `DATABASE_HOST` is set).

#### Пример использования / Usage Example

```ruby
require 'bbk/utils'

BBK::Utils::Config.instance.tap do |cfg|
  # Обязательные переменные / Required variables
  cfg.require('API_KEY', desc: 'API key for external service', secure: true)

  # Опциональные с дефолтами / Optional with defaults
  cfg.optional('LOG_LEVEL', default: 'info', desc: 'Logging level')
  cfg.optional('TIMEOUT', default: 30, type: method(:Integer), desc: 'Request timeout in seconds')

  # Булевые значения / Boolean values
  cfg.optional('DEBUG_MODE', default: false, bool: true, desc: 'Enable debug mode')

  # Кастомный парсер (например, ActiveSupport::Duration)
  # Custom parser (e.g., ActiveSupport::Duration)
  cfg.optional('CLEAN_INTERVAL', default: '3month', 
               type: method(:duration_parser), desc: 'Data retention interval')

  # Подконфигурация с префиксом / Subconfiguration with prefix
  cfg.subconfig(prefix: 'REDIS') do |redis|
    redis.optional('URL', default: 'redis://redis:6379/0', desc: 'Redis connection URL')
    redis.optional('POOL_SIZE', default: 5, type: method(:Integer), desc: 'Connection pool size')
  end
end

# Сначала нормализуем ENV (если используется EnvHelper)
# First normalize ENV (if EnvHelper is used)
BBK::Utils::EnvHelper.prepare_database_envs(ENV)
BBK::Utils::EnvHelper.prepare_mq_envs(ENV)

# Затем читаем и валидируем конфигурацию / Then read and validate configuration
BBK::Utils::Config.run!(ENV)

# Чтение значений / Reading values
log_level = BBK::Utils::Config['LOG_LEVEL']
redis_url = BBK::Utils::Config['REDIS_URL']

# Диагностика / Diagnostics
puts BBK::Utils::Config.to_s
```

`duration_parser` — пользовательская функция

Пример реализации:

```ruby
def duration_parser(raw_value)
  duration = Fugit::Duration.parse(raw_value)
  raise "#{raw_value} have invalid duration format" if duration.blank?

  ActiveSupport::Duration.parse(duration.to_iso_s)
end
```

#### Пример вывода `to_s` / Example `to_s` output

```text
Environment variables:
   <API_KEY>                                       API key for external service
      -> [FILTERED]
   [LOG_LEVEL] (=info)                             Logging level
      -> "info"
   [TIMEOUT] (=30)                                 Request timeout in seconds
      -> 30
   [DEBUG_MODE]                                    Enable debug mode
      -> false
   [REDIS_URL] (=redis://redis:6379/0)             Redis connection URL
      -> "redis://redis:6379/0"
   [REDIS_POOL_SIZE] (=5)                          Connection pool size
      -> 5
```

Обозначения / Legend:

- `<VAR>` — обязательная переменная / required variable
- `[VAR]` — опциональная переменная / optional variable
- `(=value)` — значение по умолчанию / default value


### bbkdocs

Генерация документации для BBK-библиотек / Documentation generator for BBK libraries.

Создать / Create `bin/bbkdocs`:

```ruby
#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'bbk/utils/cli'

BBK::Utils::Cli::Docs.new(ARGV).run
```

Добавить в / Add to `Rakefile`:

```ruby
# Загружаем таски из BBK::Utils. В частности генерацию документации
# Load tasks from BBK::Utils. In particular documentation generation
BBK::Utils.load_tasks
```

---

## Участие в разработке / Contributing

См. файл / See the file [CONTRIBUTING.md](./CONTRIBUTING.md)

---

## Лицензия / License

См. файл / See the file [LICENSE](./LICENSE)
