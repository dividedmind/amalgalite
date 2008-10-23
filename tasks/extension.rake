require 'tasks/config'
require 'pathname'
require 'zlib'
require 'archive/tar/minitar'

#-----------------------------------------------------------------------
# Extensions
#-----------------------------------------------------------------------

if ext_config = Configuration.for_if_exist?('extension') then
  namespace :ext do  
    desc "Build the extension(s)"
    task :build do
      ext_config.configs.each do |extension|
        path  = Pathname.new(extension)
        parts = path.split
        conf  = parts.last
        Dir.chdir(path.dirname) do |d| 
          ruby conf.to_s
          #sh "rake default"
          sh "make"
        end
      end
    end

    desc "Build the extensions for windows"
    task :build_win => :clobber do
      ext_config.configs.each do |extension|
        path = Pathname.new( extension )
        parts = path.split
        conf = parts.last
        Dir.chdir( path.dirname ) do |d|
          cp "rbconfig-mingw.rb", "rbconfig.rb"
          sh "ruby -I. extconf.rb"
          sh "make"
          rm_f "rbconfig.rb"
        end
      end
    end

    task :clean do
      ext_config.configs.each do |extension|
        path  = Pathname.new(extension)
        parts = path.split
        conf  = parts.last
        Dir.chdir(path.dirname) do |d| 
          #sh "rake clean"
          sh "make clean"
          rm_f "rbconfig.rb"
        end
      end
    end

    task :clobber do
      ext_config.configs.each do |extension|
        path  = Pathname.new(extension)
        parts = path.split
        conf  = parts.last
        Dir.chdir(path.dirname) do |d| 
          #sh "rake clobber"
          if File.exist?( "Makefile") then
            sh "make distclean"
          end
          rm_f "rbconfig.rb"
        end
      end
    end

    desc "Download and integrate the next version of sqlite"
    task :update_sqlite do
      next_version = ENV['VERSION']
      raise "VERSION env variable must be set" unless next_version
      puts "downloading ..."
      url = URI.parse("http://sqlite.org/sqlite-amalgamation-#{next_version}.tar.gz")
      file = "tmp/#{File.basename( url.path ) }"
      FileUtils.mkdir "tmp" unless File.directory?( "tmp" )
      File.open( file, "wb+") do |f|
        res = Net::HTTP.get_response( url )
        f.write( res.body )
      end

      puts "extracting..."
      upstream_files = %w[ sqlite3.h sqlite3.c sqlite3ext.h ]
      Zlib::GzipReader.open( file ) do |tgz|
        Archive::Tar::Minitar::Reader.open( tgz ) do |tar|
          tar.each_entry do |entry|
            bname = File.basename( entry.full_name )
            if upstream_files.include?( bname ) then
              dest_file = File.join( "ext", bname )
              puts "updating #{ dest_file }"
              File.open( dest_file, "wb" ) do |df|
                while bytes = entry.read do
                  df.write bytes
                end
              end
            end
          end
        end
      end
    end
  end
end
