class XmlStruct
  def initialize(xml)
    @xml = xml
    # puts "I am #{self}. Nodes: #{self.class.nodes}. Attrs: #{self.class.attrs}"
    @node_classes = create_node_classes self.class.nodes
    create_nodes self.class.nodes
    create_attrs self.class.attrs
  end

  def create_node_classes(nodes)
    result = {}
    nodes.each_key do |name|
      node = Class.new(XmlStruct)
      node.class_eval(&self.class.nodes[name])
      result[name] = node
    end
    result
  end

  def create_nodes(nodes)
    nodes.each_key do |name|
      elem = @xml.children.find { |c| c.name == name.to_s }
      unless elem
        fail "#{name} element not found"
      end

      klass = @node_classes[name]
      node = klass.new(@xml.css(name.to_s).first)
      self.define_singleton_method name do
        node
      end
    end
  end

  def create_attrs attrs
    @xml.attributes.each do |name, attr|
      value = attr.value
      attr_name, elem_name, type = attrs.find { |a| a[1] == name } || [name.to_sym, name, :string
]
      case type
      when :string
        self.define_singleton_method attr_name do
          value
        end
      when :boolean
        self.define_singleton_method attr_name do
          value.to_i == 0 ? false : true
        end
      when :integral
        self.define_singleton_method attr_name do
          value.to_i
        end
      else
        fail 'unknown type'
      end
    end
  end

  class << self
    attr_reader :nodes, :attrs

    def inherited(derived)
      derived.class_init
    end

    def class_init
      @nodes = {}
      @attrs = []
    end

    # class macros
    def node(name, &block)
      @nodes[name] = block || proc {}
    end

    def attr_bool(*names)
      names.each do |sym|
        @attrs << [sym, sym.to_s.sub(/\?$/, ''), :boolean]
      end
    end

    def attr_integral(*names)
      names.each do |sym|
        @attrs << [sym, sym.to_s, :integral]
      end
    end
  end
end

