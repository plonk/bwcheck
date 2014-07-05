require_relative 'xml_struct'

class UptestStatus < XmlStruct
  node :yp

  node :host do
    attr_bool :port_open?, :over?
    attr_integral :speed
  end

  node :uptest do
    attr_bool :checkable?
    attr_integral :remain
  end

  node :uptest_srv do
    attr_integral :port, :post_size, :limit, :interval
    attr_bool :enabled?
  end
end
