module JsonapiCompliable
  module SerializableHash
    def to_hash(fields: nil, include: {})
      {}.tap do |hash|
        _fields = fields[jsonapi_type] if fields
        attrs = requested_attributes(_fields).each_with_object({}) do |(k, v), h|
          h[k] = instance_eval(&v)
        end
        rels = @_relationships.select { |k,v| !!include[k] }
        rels.each_with_object({}) do |(k, v), h|
          serializers = v.send(:resources)
          attrs[k] = if serializers.is_a?(Array)
            serializers.map do |rr| # use private method to avoid array casting
              rr.to_hash(fields: fields, include: include[k])
            end
          else
            serializers.to_hash(fields: fields, include: include[k])
          end
        end

        hash[:id] = jsonapi_id
        hash.merge!(attrs) if attrs.any?
      end
    end
  end
  JSONAPI::Serializable::Resource.send(:include, SerializableHash)

  class HashRenderer
    def render(options)
      serializers = options[:data]
      opts = options.slice(:fields, :include)
      to_hash(serializers, opts).tap do |hash|
        hash.merge!(options.slice(:meta)) if !options[:meta].empty?
      end
    end

    private

    def to_hash(serializers, opts)
      {}.tap do |hash|
        if serializers.is_a?(Array)
          hash[serializers[0].jsonapi_type] = serializers.map do |s|
            s.to_hash(opts)
          end
        else
          hash[serializers.jsonapi_type] = serializers.to_hash(opts)
        end
      end
    end
  end
end