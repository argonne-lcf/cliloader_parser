module CLILoader

  module Files

    class << self
      attr_reader :program_sources
      attr_reader :buffer_inputs
      attr_reader :buffer_outputs
    end

    PROGRAM_SOURCE_REGEX = /CLI_(\d{4})_(\h{8})_source\.cl/
    BINARY_BUFFER_ARG_DUMP = /Enqueue_(\d+)_Kernel_(\w+?)_Arg_(\d+)_Buffer_(\d+)\.bin/
    MEMDUMP_PRE_DIR = "memDumpPreEnqueue"
    MEMDUMP_POST_DIR = "memDumpPostEnqueue"

    def self.match_program_source(dir, events)
      create_program_with_source_evts = events.select { |e|
        e.kind_of? CLILoader::CL::CreateProgramWithSource
      }
      dir.each { |file_name|
        file_name =~ PROGRAM_SOURCE_REGEX
        if $&
          program_number = $1
          program_hash = $2
          evt = create_program_with_source_evts.find { |e|
            e.infos[:"program number"] == program_number
          }
          @program_sources[File.join(dir.path,file_name)] = evt if evt
        end
      }
    end

    def self.match_buffer_binary_helper(dir, events, store, dir_name, enqueue_kernel_evts)
      begin
        Dir.open(File.join(dir.path, dir_name)) { |d|
          d.each { |file_name|
            file_name =~ BINARY_BUFFER_ARG_DUMP
            if $&
              enqueue_number = $1.to_i
              arg_number = $3.to_i
              evt = enqueue_kernel_evts.find { |e|
                e.date == enqueue_number
              }
              store[File.join(dir.path,dir_name,file_name)] = [ evt, arg_number ]
            end
          }
        }
      rescue Errno::ENOENT
      end
    end

    def self.match_buffer_binary(dir, events)
      enqueue_kernel_evts = events.select { |e|
        e.kind_of? CLILoader::CL::EnqueueNDRangeKernel
      }
      match_buffer_binary_helper(dir, events, @buffer_inputs, MEMDUMP_PRE_DIR, enqueue_kernel_evts)
      match_buffer_binary_helper(dir, events, @buffer_outputs, MEMDUMP_POST_DIR, enqueue_kernel_evts)
    end

    def self.match_files(dir, events)
      @program_sources = {}
      @buffer_inputs = {}
      @buffer_outputs = {}
      match_program_source(dir, events)
      match_buffer_binary(dir, events)
      [@program_sources, @buffer_inputs, @buffer_outputs]
    end

  end

end
