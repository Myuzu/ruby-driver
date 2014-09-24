# encoding: utf-8

require 'yard'

module Docs
  class APIDataSource < Nanoc::DataSource
    identifier :api

    def up
      YARD::Templates::Engine.register_template_path templates_dir_name
      YARD::Templates::Template.extra_includes << Helper
    end

    def lib_dir_name
      config.fetch(:lib_dir, 'lib').chomp('/') + '/'
    end

    def templates_dir_name
      config.fetch(:template_paths, 'templates')
    end

    def prefix
      'api/'
    end

    def items
      YARD::Registry.clear
      YARD::Templates::Engine.constants.each do |const|
        YARD::Templates::Engine.send(:remove_const, const) if const =~ /^Template_/
      end
      YARD.parse(lib_dir_name + '**/*.rb')

      verifier = YARD::Verifier.new('!object.tag(:private) && (object.namespace.is_a?(CodeObjects::Proxy) || !object.namespace.tag(:private))')

      verifier.run(YARD::Registry.all(:module, :class)).map do |code|
        identifier = prefix + code.title.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.gsub('::', '/')

        Nanoc::Item.new(code.format({
          :format   => :html,
          :template => :docs,
          :markup   => :markdown,
          :verifier => verifier,
          :prefix   => prefix
        }), {:title => code.name}, identifier)
      end
    end
  end

  private

  module Helper
    def html_syntax_highlight_ruby(source)
      markup = ::Rouge.highlight(source, 'ruby', 'html')
      markup.sub!(/<pre><code class="highlight">/,'<pre class="highlight"><code class="ruby">')
      markup.sub!(/<\/code><\/pre>/,"</code></pre>")
      markup.strip!
      markup
    end

    def htmlify_line(*args)
      htmlify(*args).sub('<p>', '').chomp('</p>')
    end

    def format_return_types(object)
      return unless object.has_tag?(:return) && object.tag(:return).types
      return if object.tag(:return).types.empty?
      format_types object.tag(:return).types, false
    end

    def format_types(typelist, brackets = true)
      return unless typelist.is_a?(Array)
      list = typelist.map do |type|
        type = type.gsub(/([<>])/) { h($1) }
        type = type.gsub(/([#\w:]+)/) { $1 == "lt" || $1 == "gt" ? $1 : linkify($1, $1) }
        type
      end
      return if list.empty?

      if list.one?
        list.first
      else
        (brackets ? "(#{type_list_join(list)})" : type_list_join(list))
      end
    end

    def type_list_join(list)
      index = 0
      size  = list.size
      list.each_with_object('') do |item, out|
        out << item.to_s
        out << ", " if index < size - 2
        out << " or " if index == size - 2
        index += 1
      end
    end

    def link_object(obj, title = nil, anchor = nil, relative = true)
      return title if obj.nil?
      obj = ::YARD::Registry.resolve(object, obj, true, true) if obj.is_a?(String)
      if title
        title = title.to_s
      elsif object.is_a?(::YARD::CodeObjects::Base)
        # Check if we're linking to a class method in the current
        # object. If we are, create a title in the format of
        # "CurrentClass.method_name"
        if obj.is_a?(::YARD::CodeObjects::MethodObject) && obj.scope == :class && obj.parent == object
          title = h([object.name, obj.sep, obj.name].join)
        elsif obj.title != obj.path
          title = h(obj.title)
        else
          title = h(object.relative_path(obj))
        end
      else
        title = h(obj.to_s)
      end
      return "<code>#{title}</code>" if obj.is_a?(::YARD::CodeObjects::Proxy)

      title.sub!('Cassandra::', '')

      link = url_for(obj, anchor)
      link = link ? link_url(link, title, :title => h("#{obj.title} (#{obj.type})")) : title
      "<code>#{link}</code>"
    end

    def url_for(obj, anchor = nil, relative = true)
      link = nil
      return link if obj.is_a?(::YARD::CodeObjects::Base) && run_verifier([obj]).empty?

      if obj.is_a?(::YARD::CodeObjects::Base) && !obj.is_a?(::YARD::CodeObjects::NamespaceObject)
        # If the obj is not a namespace obj make it the anchor.
        anchor, obj = obj, obj.namespace
      end

      objpath = serialized_path(obj)
      return link unless objpath

      link = objpath
      link + (anchor ? '#' + urlencode(anchor_for(anchor)) : '')
    end

    def serialized_path(object)
      return object if object.is_a?(String)

      identifier = '/' + options.prefix + object.title.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.gsub('::', '/') + '/'
      identifier.sub('api/cassandra', 'api')
    end
  end
end
