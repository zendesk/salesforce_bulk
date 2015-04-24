module SalesforceBulk

  # Interface for operating the Salesforce Bulk REST API
  class Client
    # The host to use for authentication. Defaults to login.salesforce.com.
    attr_accessor :login_host

    # The instance host to use for API calls. Determined from login response.
    attr_accessor :instance_host

    # The Salesforce password
    attr_accessor :password

    # The Salesforce username
    attr_accessor :username

    # The API version the client is using. Defaults to 24.0.
    attr_accessor :version

    def initialize(options={})
      if options.is_a?(String)
        options = YAML.load_file(options)
        options.symbolize_keys!
      end

      options = {:login_host => 'login.salesforce.com', :version => 24.0}.merge(options)

      options.assert_valid_keys(:username, :password, :login_host, :version)

      self.username = options[:username]
      self.password = "#{options[:password]}"
      self.login_host = options[:login_host]
      self.version = options[:version]

      @api_path_prefix = "/services/async/#{version}/"
      @valid_operations = [:delete, :insert, :update, :upsert, :query]
      @valid_concurrency_modes = ['Parallel', 'Serial']
    end

    def authenticate
      xml = '<?xml version="1.0" encoding="utf-8"?>'
      xml += '<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema"'
      xml += ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
      xml += ' xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">'
      xml += "<env:Body>"
      xml += '<n1:login xmlns:n1="urn:partner.soap.sforce.com">'
      xml += "<n1:username>#{username}</n1:username>"
      xml += "<n1:password>#{password}</n1:password>"
      xml += "</n1:login>"
      xml += "</env:Body>"
      xml += "</env:Envelope>\n"

      response = http_post("/services/Soap/u/#{version}", xml, 'Content-Type' => 'text/xml', 'SOAPAction' => 'login')

      data = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      result = data['Body']['loginResponse']['result']

      @session_id = result['sessionId']

      self.instance_host = "#{instance_id(result['serverUrl'])}.salesforce.com"
      self
    end

    def abort_job(jobId)
      xml = '<?xml version="1.0" encoding="utf-8"?>'
      xml += '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload">'
      xml += "<state>Aborted</state>"
      xml += "</jobInfo>"

      response = http_post("job/#{jobId}", xml)
      data = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      Job.new_from_xml(data)
    end

    def add_batch(jobId, data)
      body = data

      if data.is_a?(Array)
        raise ArgumentError, "Data set exceeds 10000 record limit by #{data.length - 10000}" if data.length > 10000

        keys = data.first.keys
        body = keys.to_csv

        data.each do |item|
          item_values = keys.map { |key| item[key] }
          body += item_values.to_csv
        end
      end

      # Despite the content for a query operation batch being plain text we
      # still have to specify CSV content type per API docs.
      response = http_post("job/#{jobId}/batch", body, "Content-Type" => "text/csv; charset=UTF-8")
      result = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      Batch.new_from_xml(result)
    end

    def add_job(operation, sobject, options={})
      operation = operation.to_s.downcase.to_sym

      raise ArgumentError.new("Invalid operation: #{operation}") unless @valid_operations.include?(operation)

      options.assert_valid_keys(:external_id_field_name, :concurrency_mode)

      if options[:concurrency_mode]
        concurrency_mode = options[:concurrency_mode].capitalize
        raise ArgumentError.new("Invalid concurrency mode: #{concurrency_mode}") unless @valid_concurrency_modes.include?(concurrency_mode)
      end

      xml = '<?xml version="1.0" encoding="utf-8"?>'
      xml += '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload">'
      xml += "<operation>#{operation}</operation>"
      xml += "<object>#{sobject}</object>"
      xml += "<externalIdFieldName>#{options[:external_id_field_name]}</externalIdFieldName>" if options[:external_id_field_name]
      xml += "<concurrencyMode>#{options[:concurrency_mode]}</concurrencyMode>" if options[:concurrency_mode]
      xml += "<contentType>CSV</contentType>"
      xml += "</jobInfo>"

      response = http_post("job", xml)
      data = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      job = Job.new_from_xml(data)
    end

    def batch_info_list(jobId)
      response = http_get("job/#{jobId}/batch")
      result = XmlSimple.xml_in(response.body, 'ForceArray' => false)

      if result['batchInfo'].is_a?(Array)
        result['batchInfo'].collect do |info|
          Batch.new_from_xml(info)
        end
      else
        [Batch.new_from_xml(result['batchInfo'])]
      end
    end

    def batch_info(jobId, batchId)
      response = http_get("job/#{jobId}/batch/#{batchId}")
      result = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      Batch.new_from_xml(result)
    end

    def batch_result(jobId, batchId)
      response = http_get("job/#{jobId}/batch/#{batchId}/result")

      if response.body =~ /<.*?>/m
        result = XmlSimple.xml_in(response.body)

        if result['result'].present?
          results = query_result(jobId, batchId, result['result'].first)

          collection = QueryResultCollection.new(self, jobId, batchId, result['result'].first, result['result'])
          collection.replace(results)
        end
      else
        result = BatchResultCollection.new(jobId, batchId)

        CSV.parse(response.body, :headers => true) do |row|
          result << BatchResult.new(row[0], row[1].to_b, row[2].to_b, row[3])
        end

        result
      end
    end

    def query_result(job_id, batch_id, result_id)
      headers = {"Content-Type" => "text/csv; charset=UTF-8"}
      response = http_get("job/#{job_id}/batch/#{batch_id}/result/#{result_id}", headers)

      lines = response.body.lines.to_a
      headers = CSV.parse_line(lines.shift).collect { |header| header.to_sym }

      result = []

      #CSV.parse(lines.join, :headers => headers, :converters => [:all, lambda{|s| s.to_b if s.kind_of? String }]) do |row|
      CSV.parse(lines.join, :headers => headers) do |row|
        result << Hash[row.headers.zip(row.fields)]
      end

      result
    end

    def close_job(jobId)
      xml = '<?xml version="1.0" encoding="utf-8"?>'
      xml += '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload">'
      xml += "<state>Closed</state>"
      xml += "</jobInfo>"

      response = http_post("job/#{jobId}", xml)
      data = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      Job.new_from_xml(data)
    end

    def job_info(jobId)
      response = http_get("job/#{jobId}")
      data = XmlSimple.xml_in(response.body, 'ForceArray' => false)
      Job.new_from_xml(data)
    end

    def http_post(path, body, headers={})
      headers = {'Content-Type' => 'application/xml'}.merge(headers)

      if @session_id
        headers['X-SFDC-Session'] = @session_id
        host = instance_host
        path = "#{@api_path_prefix}#{path}"
      else
        host = self.login_host
      end

      response = https_request(host).post(path, body, headers)

      if response.is_a?(Net::HTTPSuccess)
        response
      else
        raise SalesforceError.new(response)
      end
    end

    def http_get(path, headers={})
      path = "#{@api_path_prefix}#{path}"

      headers = {'Content-Type' => 'application/xml'}.merge(headers)

      if @session_id
        headers['X-SFDC-Session'] = @session_id
      end

      response = https_request(self.instance_host).get(path, headers)

      if response.is_a?(Net::HTTPSuccess)
        response
      else
        raise SalesforceError.new(response)
      end
    end

    def https_request(host)
      req = Net::HTTP.new(host, 443)
      req.use_ssl = true
      req.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req
    end

    def instance_id(url)
      url.match(/:\/\/([a-zA-Z0-9\-\.]{2,}).salesforce/)[1]
    end
  end
end
