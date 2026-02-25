module Env
  class CategoryBuilder

    def initialize(env_vars_hash, app_config_path = nil, gem_config_path = nil)
      @env_vars = env_vars_hash
      @app_config = load_yaml_config(app_config_path)
      @gem_config = load_yaml_config(gem_config_path)
    end
    
    def run
      categories = {}
      
      # ШАГ 1: Сначала загружаем базовые категории из гема (самый низкий приоритет)
      load_gem_config(categories)
      
      # ШАГ 2: Дополняем и переопределяем из конфига приложения
      load_app_config(categories)
      
      # ШАГ 3: Дополняем и переопределяем из env_vars (высший приоритет)
      load_env_vars_categories(categories)
  
      # ШАГ 4: Распределяем переменные по категориям
      assign_vars_to_categories(categories)
  
      # ШАГ 5: Добавляем uncategorized
      add_uncategorized_category(categories)
  
      categories = sort_categories(categories)
    end
  
    def categories_inspect(categories)
      result = {}
      categories.each do |k, v|
        result[k] = v.as_json
      end
      JSON.pretty_generate(result)
    end
    
    private
    
    def load_yaml_config(path)
      YAML.load_file(path)['categories'] if File.exist?(path)
    end
    
    def load_gem_config(categories)
      return unless @gem_config
      
      @gem_config.each do |category_id, config|
        cat_id = category_id.to_sym
        
        # Создаем с базовыми значениями из гема
        categories[cat_id] = Category.new(
          id: cat_id,
          name: config['name'],
          name_ru: config['name_ru'],
          desc: config['desc'],
          desc_ru: config['desc_ru'],
          order: config['order'] || Float::INFINITY,
          env_patterns: config['env_patterns'] || [],
          envs: config['envs']
        )
      end
    end
  
    def load_app_config(categories)
      return unless @app_config
      
      @app_config.each do |category_id, config|
        cat_id = category_id.to_sym
        
        if c = categories[cat_id]
          # Категория уже есть из гема - обновляем только то, что указано в app_config
          c.update(
            name: config.fetch('name', c.name),
            name_ru: config.fetch('name_ru', c.name_ru),
            desc: config.fetch('desc', c.desc),
            desc_ru: config.fetch('desc_ru', c.desc_ru),
            order: config.fetch('order', c.order),
            # envs и env_patterns - особый случай: они ДОБАВЛЯЮТСЯ, а не заменяются
            envs: merge_envs(c.envs, config['envs']),
            env_patterns: merge_patterns(c.env_patterns, config['env_patterns'])
          )
        else
          # Новая категория, которой не было в геме
          categories[cat_id] = Category.new(
            id: cat_id,
            name: config['name'],
            name_ru: config['name_ru'],
            desc: config['desc'],
            desc_ru: config['desc_ru'],
            order: config['order'] || Float::INFINITY,
            env_patterns: config['env_patterns'] || [],
            envs: config['envs']
          )
        end
      end
    end
  
    def load_env_vars_categories(categories)
      @env_vars.each do |env_name, env_data|
        category_id = env_data[:category]
        next unless category_id
        
        cat_id = category_id.to_sym
        
        if categories[cat_id]
          # Категория уже существует - просто добавим в defined_vars
          categories[cat_id].add_defined_vars(env_name)
        else
          # Создаем новую категорию из env_vars
          categories[cat_id] = Category.new(
            id: cat_id,
            name: category_id.to_s.capitalize
          )
          categories[cat_id].add_defined_vars(env_name)
        end
      end
    end
    
    def assign_vars_to_categories(categories)
      @env_vars.each do |env_name, env_data|
        assigned = false
        
        categories.each do |_, category|
          if category.envs&.include?(env_name)
            category.add_env_var(env_name, env_data)
            assigned = true
          end
        end
        
        categories.each do |_, category|
          if category.defined_vars.include?(env_name)
            category.add_env_var(env_name, env_data)
            assigned = true
          end
        end
        
        categories.each do |_, category|
          category.env_patterns.each do |pattern|
            if env_name.start_with?(pattern)
              category.add_env_var(env_name, env_data)
              assigned = true
              break
            end
          end
        end
        
        @env_vars[env_name][:_assigned] = assigned
      end
    end
  
    def add_uncategorized_category(categories)
      unassigned_vars = @env_vars.reject { |_, data| data[:_assigned] }
      
      return if unassigned_vars.empty?
      
      categories[:uncategorized] ||= Category.new(
        id: :uncategorized,
        name: 'Uncategorized',
        name_ru: 'Без категории',
        desc: 'Environment variables without category',
        desc_ru: 'Переменные окружения без категории',
        order: Float::INFINITY,
        source: :system
      )
      
      unassigned_vars.each do |env_name, env_data|
        categories[:uncategorized].add_env_var(env_name, env_data)
      end
    end
    
    def sort_categories(categories)
      categories.sort_by { |_, category| [category.order, category.id.to_s] }.to_h
    end
  
    def merge_envs(existing, new)
      return existing unless new
      return new unless existing
      (existing + new).uniq
    end
  
    def merge_patterns(existing_patterns, new_patterns)
      return existing_patterns unless new_patterns
      return new_patterns unless existing_patterns
      
      (existing_patterns + new_patterns).uniq
    end
  end
  
  class Category
    attr_reader :id, :name, :name_ru, :desc, :desc_ru, :env_vars, :order,
                :env_patterns, :envs, :source, :defined_vars
    
    def initialize(id:, name: nil, name_ru: nil, desc: nil, desc_ru: nil, 
                   env_patterns: [], envs: nil, order: Float::INFINITY,
                   source: nil)
      @id = id
      @name = name || id.to_s.capitalize
      @name_ru = name_ru
      @desc = desc
      @desc_ru = desc_ru
      @env_patterns = env_patterns || []
      @envs = envs
      @order = order
      @source = source
      @env_vars = {}
      @defined_vars = Set.new # это переменные, определенные в bbk_conf (пришли из BBK::Utils::Config) и имеющие категорию
    end
    
    def update(attrs)
      attrs.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
    
    def add_defined_vars(env_name)
      @defined_vars.add(env_name)
    end
    
    def add_env_var(name, data)
      @env_vars[name] = data
    end
    
    def sorted_env_vars
      # # Задумка была сначала явные переменные в их порядке, а потом остальные
      # # TODO про порядок подумать потом, если нужно
      # if envs
      #   # Сначала переменные из envs в заданном порядке
      #   vars = envs.map { |env| [env, @env_vars[env]] }
      #                                .select { |_, data| data }
      #                                .to_h
      # 
      #   # Затем все остальные переменные по алфавиту
      #   other_vars = @env_vars.reject { |env, _| envs.include?(env) }
      #                         .sort
      #                         .to_h
      # 
      #   # Объединяем
      #   vars.merge(other_vars)
      # else
      #   @env_vars.sort.to_h
      # end
  
      @env_vars.sort.to_h
    end
    
    def as_json(*_args)
      {
        id: @id,
        name: @name,
        name_ru: @name_ru,
        desc: @desc,
        desc_ru: @desc_ru,
        env_patterns: @env_patterns,
        envs: @envs,
        order: @order == Float::INFINITY ? "Infinity" : @order,
        defined_vars: @defined_vars.to_a,
        #env_vars: @env_vars,
        #env_vars_keys: @env_vars.keys,
        #env_vars_count: @env_vars.size
      }
    end
  
    def to_json(*_args)
      as_json.to_json(*args)
    end
    
    def inspect
      as_json.inspect
    end
  
  end
end
