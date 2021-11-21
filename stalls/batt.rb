#
#   batt.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

class Batt < StringStall
  def build
    @max_capacity = full_capacity
    @progress_count = 0
    @progress_max = 2
    @level=100
    @alert_level = conf("alert_level").to_i
    attach_task(10,self,:update_charging_state)
    attach_task(1,self,:update)
    @widget = add_widget(StringWidget.new(self))
    update_charging_state
    update
  end
  
  def check
    File.exists?("#{self.conf('info_dir')}/status")
  end
  
  def progress(_side='left')
    if @progress_count >= @progress_max
      @progress_count=1
    else
      @progress_count=@progress_count+1
    end
    if _side == 'left'
      _char='<'
    else
      _char='>'
    end
    str=''
    @progress_count.times{str << _char}
    if _side == 'left'
      return str.rjust(@progress_max)
    else
      return str.ljust(@progress_max)
    end
  end
  
  def update
    if @last_c_state == 'full' && @widget.visible
      hide_widget(@widget)
    elsif @last_c_state != 'full' && !@widget.visible
      show_widget(@widget)
    end
    if @widget.visible
      @widget.value = build_value(@last_c_state, @level)
      refresh_widget(@widget) if !@widget.blinking?
    end
  end
  
  def build_value(_c_state, _level)
    suf="BATT"
    if _c_state == 'charging'
      suf="#{suf} #{progress('right')} "
    elsif _c_state == 'full'
      suf="#{suf} <> "
    else
      suf="#{suf} #{progress('left')} "
    end
    suf+"%3d".%(_level)+' %'    
  end
  
  def update_charging_state
    c_state = charging_state
    if c_state != 'full' || c_state !=@last_c_state 
      @level = (cur_capacity * 100 / @max_capacity)
      @widget.value = build_value(c_state, @level)
      if @level < @alert_level && !@widget.blinking? && c_state != 'charging'
        @widget.start_blink
      elsif (@level >= @alert_level || c_state == 'charging') && @widget.blinking? 
        @widget.stop_blink 
      end
    end
    @last_c_state=c_state
  end

  def full_capacity
    res = 0
    open("#{self.conf('info_dir')}/charge_full","r"){|f|
       res = f.read.strip.to_i
    }
    res
  end


  def full_capacity_old
    res = 0
    open("|grep #{'"'}last full capacity:#{'"'} #{self.conf('info_dir')}/info | awk '{print $4}'","r"){|f|
       res = f.read.strip.to_i
    }
    res
  end

  def cur_capacity
    res = 0
    open("#{self.conf('info_dir')}/charge_now","r"){|f|
       res = f.read.strip.to_i
    }
    res
  end

  def cur_capacity_old
    res = 0
    open("|grep #{'"'}remaining capacity:#{'"'} #{self.conf('info_dir')}/state | awk '{print $3}'","r"){|f|
       res = f.read.strip.to_i
    }
    res
  end
 
 def charging_state 
    res = ''
    open("#{self.conf('info_dir')}/status","r"){|f|
       res = f.read.strip.downcase
    }
    res
  end
 
  def charging_state_old 
    res = ''
    open("|grep #{'"'}charging state:#{'"'} #{self.conf('info_dir')}/state | awk '{print $3}'","r"){|f|
       res = f.read.strip
    }
    res
  end
end