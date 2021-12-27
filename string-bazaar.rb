#
#   string-bazaar.rb - wmii-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

require "observer"
require "open3"
Dir.chdir("#{File.dirname(__FILE__)}")
module LogLevel
  FATAL=5
  ERROR=4
  WARN=3
  INFO=2
  DEBUG=1
  TRACE=0
  def LogLevel.level_string(_level)
    case _level
    when 5
      return "FATAL"
    when 4
      return "ERROR"
    when 3
      return "WARN"
    when 2
      return "INFO"
    when 1
      return "DEBUG"
    when 0
      return "TRACE"
    end
  end
end

class StringBazaar
  attr_reader :widgets
  attr_reader :controller
  attr_reader :str
  def initialize(_controller)
    @controller=_controller
    @widgets = Array.new
    @refresh_required = false
    @sep = @controller.conf('output.text.sep').gsub('\s', " ")
    @sep_begin = @controller.conf('output.text.sep.begin').gsub('\s', " ")
    @sep_end = @controller.conf('output.text.sep.end').gsub('\s', " ")
  end

  def system_send(_cmd,_info="StringBazaar")
    @controller.system_send(_cmd,_info)
  end

  def add_widget(_widget)
    _widget.bazaar=self
    show_widget(_widget)
    @widgets << _widget
    _widget
  end

  def update_widget(_widget)
    @refresh_required = true
  end

  def remove_widget(_widget)
    hide_widget(_widget)
    @widgets.delete(_widget)
  end

  def hide_widget(_widget)
    _widget.visible = false
  end

  def show_widget(_widget)
    _widget.visible = true
  end

  def finalize
    #@widgets.each{|w| system("wmiir remove /rbar/#{w.name} 2>/dev/null")}
    #system("wmiir remove /rbar/#{BAR_NAME} 2>/dev/null")
  end

  def build_string
    str = ''
    @widgets.each{|w|
      if w.visible
        str += @sep if str.length>0
        if w.blinking? && !w.blink_on
          str += " "*w.value.length
        else
          str += w.value
        end
      end
    }
    @str = "#{@sep_begin}#{str}#{@sep_end}"
  end
  
  def build_string_i3bar_json
    str = ''
    @widgets.each{|w|
      if w.visible
        str += "," if str.length>0
        str += "{"
        if w.blinking? && !w.blink_on
          str += "\"full_text\":\"#{" "*w.value.length}\""
        else
          str += "\"full_text\":\"#{w.value}\""
        end
        #i3 property
        w.stall.conf_group("i3bar").each{|prop|
          str += ",\"#{prop[0]}\":\"#{prop[1]}\""
        }
        str += "}"
      end
    }
    @str = "[#{str}],\n"
  end

  def refresh
    if @controller.conf('output') == "i3bar-json"
      build_string_i3bar_json
    else
      build_string
    end
    @refresh_required = false
  end

end

class StringBazaarController
  include Observable
  attr_reader :stalls
  def initialize
    load_config
    local_dir = File.expand_path(conf('home.dir'))
    if local_dir && !File.exist?(local_dir)
      Dir.mkdir(local_dir)
      @first_run = true
    end
  end

  def start(_bazaar, _cmd)
    log(self,"start StringBazaarController",LogLevel::INFO)
    @bazaar=_bazaar
    @cmd=_cmd
    @stalls_list=conf('stalls.list').split(',').collect!{| wi | wi.strip}
    @stalls_dir= "#{Dir.pwd}/#{self.conf('stalls.dir')}"
    @stalls_dir_local="#{File.expand_path(conf('home.dir'))}/#{self.conf('stalls.dir')}"
    @stalls=Hash.new
    @tasks=Array.new
    @task_id = 0
    load_stalls
    mainloop
  end

  def conf(_property, _value=nil)
    if !_value.nil?
      @props[_property] = _value
    end
    @props[_property]
  end

  def conf_group(_group)
    @conf_groups = Hash.new if !defined?(@conf_groups)
    if @conf_groups[_group].nil?
      @conf_groups[_group] = Hash.new
      glen=_group.length
      @props.keys.sort.each{|k|
        if k[0..glen] == "#{_group}."
          @conf_groups[_group][k[glen+1..-1]]=@props[k]
        elsif @conf_groups[_group].length > 0
          break
        end
      }
    end
    @conf_groups[_group]
  end

  def system_send(_cmd, _info="exec")
    to_ret = ''
    error = ''
    Open3.popen3(_cmd){|stdin, stdout, stderr|
      stdout.each do |line|
        to_ret = to_ret+line
      end
      stderr.each do |line|
        error+=line
      end
    }
    log(@name, "on #{_info}: #{_cmd} execution : #{to_ret}",LogLevel::TRACE)
    if error && error.strip.length > 0
      log(@name, "on #{_info}: #{_cmd} execution : #{error}",LogLevel::ERROR)
    end
    to_ret
  end


  def log(_caller, _msg, _level=LogLevel::TRACE)
    if _level >= conf('log.level').to_i
      log_file = File.expand_path(conf('log.file'))
      if !File.exists?(log_file)
        File.new(log_file, File::CREAT).close
      end
      if FileTest::exist?(log_file) && File.stat(log_file).writable?
        f = File.new(log_file, "a")
        begin
          if f
            f.syswrite(Time.new.strftime("#{LogLevel.level_string(_level)} at %a %d-%b-%Y %H:%M:%S : #{_caller} : #{_msg}\n"))
          end
        ensure
          f.close unless f.nil?
        end
      end
    end
    #    end
  end

  def load_config_from_file(_property_file, _hash)
    if _property_file &&  FileTest::exist?(_property_file)
      f = File::open(_property_file,'r')
      begin
        _lines = f.readlines
        _lines.each{|_line|
          _strip_line = _line.strip
          if (_strip_line.length > 0)&&(_strip_line[0,1]!='#')
            var = _line.split('=')
            if var.length > 1
              _value = var[1].strip
              var[2..-1].collect{|x| _value=_value+'='+x} if var.length > 2
              _hash[var[0].strip]=_value
            end
          end
        }
      ensure
        f.close unless f.nil?
      end
    end
    _hash
  end

  def load_config
    @property_file=__FILE__.sub(".rb",".conf")
    @props = load_config_from_file(@property_file, Hash.new)
    @global_props=Hash.new.update(@props)
    @local_property_file="#{File.expand_path(conf('home.dir'))}/#{File.basename(@property_file)}"
    @props = load_config_from_file(@local_property_file, @props)
    if !FileTest::exist?(@local_property_file)
      if !FileTest::exist?(File.expand_path(conf('home.dir')))
        Dir.mkdir(File.expand_path(conf('home.dir')))
      end
      f = File.new(@local_property_file, "w+")
      begin
        File.open(@property_file) do |input|
          input.readlines.each{|line|
            if line.strip.length > 0
              line = "#"+line
            end
            f.syswrite(line)
          }
        end
      ensure
        f.close unless f.nil?
      end
    end

    # -- reash
    # inherited
    to_update_hash  = Hash.new
    to_deley_keys = Array.new
    @props.each{|key,value|
      new_value=sub_from_hash(value,@global_props,"@@{")
      if new_value[0..0]=='!'
        open("|#{new_value[1..-1]}","r"){|f|
          new_value = f.read.strip
        }
      end
      new_key=sub_from_hash(key,@global_props,"@@{")
      #@props[new_key]=new_value
      to_update_hash[new_key]=new_value
      if new_key != key
        to_deley_keys << key
        #@props.delete(key)
      end
    }
    @props.update(to_update_hash)
    to_deley_keys.each{|k|
      @props.delete(k)
    }

    # contextual
    to_update_hash  = Hash.new
    to_deley_keys = Array.new
    @props.each{|key,value|
      new_value=sub_from_hash(value,@props)
      if new_value[0..0]=='!'
        open("|#{new_value[1..-1]}","r"){|f|
          new_value = f.read.strip
        }
      end
      new_key=sub_from_hash(key,@props)
      #@props[new_key]=new_value
      to_update_hash[new_key]=new_value
      if new_key != key
        to_deley_keys << key
        #@props.delete(key)
      end
    }
    @props.update(to_update_hash)
    to_deley_keys.each{|k|
      @props.delete(k)
    }
  end

  def sub_from_hash(_value,_hash,_left_sep="@{",_right_sep="}")
    new_value = _value
    while new_value.include?(_left_sep)
      key_to_find = new_value.split(_left_sep)[1].split[0]
      if key_to_find.include?(_right_sep)
        key_to_find= key_to_find.split(_right_sep)[0]
        key_to_find_with_sep= "#{_left_sep}#{key_to_find}#{_right_sep}"
      end
      if _hash[key_to_find]
        to_sub = _hash[key_to_find]
      else
        to_sub = "<KEY '#{key_to_find}' NOT FOUND!"
      end
      new_value=new_value.sub(key_to_find_with_sep,to_sub)
    end
    new_value
  end

  def load_stalls
    @stalls_list.each{|stall_name|
      stall_base_name=stall_name.split("@@@")[0]
      file_local = "#{@stalls_dir_local}/#{stall_base_name}.rb"
      file_etc = "#{@stalls_dir}/#{stall_base_name}.rb"
      if File.exists?(file_local)
        file = file_local
      elsif File.exists?(file_etc)
        file = file_etc
      else
        log(self,"Stall <<#{stall_name}>> not found!",LogLevel::ERROR)
        next
      end
      eval("require '#{file}'")
      class_name = stall_base_name.capitalize
      stall = eval(class_name).new(self, stall_name)
      @stalls[stall_name]=stall
      if stall.check
        stall.build
      end
    }
  end


  def add_widget(widget)
    @bazaar.add_widget(widget)
  end

  def remove_widget(widget)
    @bazaar.remove_widget(widget)
  end

  def hide_widget(widget)
    @bazaar.hide_widget(widget)
  end

  def show_widget(widget)
    @bazaar.show_widget(widget)
  end

  def refresh_widget(_widget)
    @bazaar.update_widget(_widget)
  end

  def str
    @bazaar.str
  end

  def new_task
    @task_id = @task_id+1
    @task_id
  end

  def attach_task(_gap=1, _worker=nil, _method=:update)
    task_id = new_task
    @tasks<<{:task_id=>task_id,:gap =>_gap,:worker =>_worker, :method =>_method, :count=>0}
    task_id
  end

  def detach_task(_task_id=nil)
    @tasks.delete_if {|x| x[:task_id] == _task_id }
  end

  def mainloop_begin
    if conf('output') == 'i3bar-json'
      system(@cmd.gsub('<<str>>', '{"version":1}\n[\n'))
    else
      system(@cmd.gsub('<<str>>', "string-bazaar"))
    end
  end

  def mainloop_end
    if conf('output') == 'i3bar-json'
      system(@cmd.gsub('<<str>>', ']\n'))
    else
    
    end
  end

  def mainloop
    mainloop_begin
    j=0
    unit = conf('stalls.main-loop-lapse').to_i
    loop {
      j=j+unit
      tasks_number = @tasks.length
      @tasks.each_with_index{|t, i|
        t[:count]=t[:count]+1
        if t[:count] >= t[:gap]
          t[:count] = 0
          Thread.new do
            begin
              #log(t[:task_id],"Mainloop task => #{t[:worker]}.#{t[:method]}",LogLevel::TRACE)
              t[:worker].send(t[:method])
            rescue Exception,LoadError
              msg = "on executing Task \"#{t[:worker]}.#{t[:method]}\" (#{$!.class.to_s}) : #{$!} at : #{$@.to_s}"
              log(t[:task_id],msg,LogLevel::ERROR)
            end
          end
        end
      }
      break if @stopping
      sleep(unit)
      @bazaar.refresh
      #p @cmd.gsub('<<str>>', @bazaar.str)
      #system("echo ciao")
      system(@cmd.gsub('<<str>>', @bazaar.str))
    }
    mainloop_end
    finalize
  end




  def finalize
    @tasks.clear
    @bazaar.finalize
  end

  def StringBazaarController::start(_cmd="echo '<<str>>'")
    instance = self.new
    instance.start(StringBazaar.new(instance), _cmd)
  end

  def StringBazaarController::stop
    #system("wmiir xwrite /event #{WmiiBazaarController::STOP_EVENT}")
    #system("wmiir remove /rbar/#{WmiiBazaar::BAR_NAME} 2>/dev/null")
  end

  def StringBazaarController::restart
    StringBazaarController::stop
    StringBazaarController::start
  end

end

class StringWidget
  attr_accessor :value
  attr_accessor :visible
  attr_accessor :bazaar
  attr_reader :name
  attr_reader :stall
  attr_reader :blink_on

  def initialize(_stall)
    @stall = _stall
    @name = _stall.name
    @visible = false
    @blinking = false
  end

  # blinking capability
  def blinking?
    @blinking
  end

  def start_blink
    return if @blinking
    @blink_on=false
    @id_blink = @bazaar.controller.attach_task(1,self,:update_blink)
    @blinking = true
  end

  def stop_blink
    return if !@blinking
    @bazaar.controller.detach_task(@id_blink) if @id_blink
    @blinking = false
    @bazaar.controller.refresh_widget(self)
  end

  def update_blink
    @blink_on = !@blink_on
    @bazaar.controller.refresh_widget(self)
    #self.value = value_save
  end

end

class StringStall
  attr_reader :name
  def initialize(_string_controller, _name)
    @string_controller = _string_controller
    @name = _name
  end

  def system_or_instance_send(_cmd, _info="exec")
    if _cmd[0..0]=="%"
      self.instance_eval(_cmd[1..-1]) if self.respond_to?(_cmd[1..-1])
    else
      system_send(_cmd, _info)
    end
  end

  def conf(_property, _value=nil)
    if !_value.nil?
       @string_controller.conf("stalls.conf.#{@name}.#{_property}", _value)
    else
      _conf_value = @string_controller.conf("stalls.conf.#{@name}.#{_property}")
      if _conf_value.nil?
        _conf_value = @string_controller.conf("stalls.conf.#{_property}")
        @string_controller.conf("stalls.conf.#{@name}.#{_property}", _conf_value)
      end
      _conf_value
    end 
  end

  def conf_group(_group)
    @string_controller.conf_group("stalls.conf.#{@name}.#{_group}")
  end

  def global_conf(_property)
    @string_controller.conf(_property)
  end

  def global_conf_group(_group)
    @string_controller.conf_group(_group)
  end

  def system_send(_cmd, _info="#{@name} exec")
    @string_controller.system_send(_cmd, _info)
  end

  def log(_caller, _msg, _level=5)
    @string_controller.log(_caller, _msg, _level)
  end

  def check
    true
  end

  def build
    attach_task(conf('lapse').to_i,self,:update)
    @widget = add_widget(StringWidget.new(self))
    update
  end

  def update
  end

  def attach_task(_gap=1, _worker=self, _method=:update)
    @string_controller.attach_task(_gap, _worker, _method)
  end

  def detach_task(_task_id=nil)
    @string_controller.detach_task(_task_id)
  end

  def refresh_widget(_widget)
    @string_controller.refresh_widget(_widget)
  end

  def add_widget(_widget)
    @string_controller.add_widget(_widget)
  end

  def remove_widget(_widget)
    @string_controller.remove_widget(_widget)
  end

  def hide_widget(_widget)
    @string_controller.hide_widget(_widget)
  end

  def show_widget(_widget)
    @string_controller.show_widget(_widget)
  end

end
