#
#   wifi.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

class Wifi < StringStall

# function wifiInfo(adapter)
#     spacer = " "
#     local f = io.open("/sys/class/net/"..adapter.."/wireless/link")
#     local wifiStrength = f:read()
#     if wifiStrength == "0" then
#         wifiStrength = "Network Down"
#     else
#         wifiStrength = "Wifi:"..spacer..wifiStrength.."%"
#     end
#     wifiwidget.text = spacer..wifiStrength..spacer
#     f:close()
# end

  def build
    @level=0
    @alert_level = conf("alert_level").to_i
    @ip_nil="?"
    @ip_addr=@ip_nil
    attach_task(5,self,:update)
    @widget = add_widget(StringWidget.new(self))
    update
  end
  
  def check
    #File.exists?("#{self.conf('info_dir')}/wireless/link")
    File.exists?("#{self.conf('info_dir')}/carrier")
  end
 
  def connected?
    res=0
    open("#{self.conf('info_dir')}/carrier","r"){|f|
       begin
         value = f.read
         res = value.strip.to_i
       rescue  Errno::EINVAL => e
         res = 0
       end   
    }
    res==1
  end
  
  def update
    @level = current_level
    if @level <= 0 && @widget.visible
      hide_widget(@widget)
      @ip_addr=@ip_nil
    elsif @level > 0 && !@widget.visible
      show_widget(@widget)
    end
    if @widget.visible
      @widget.value = build_value(@level)
      refresh_widget(@widget) if !@widget.blinking?
    end
    if (@level <= @alert_level || @ip_addr==@ip_nil) && !@widget.blinking?
      @widget.start_blink
    elsif @level > @alert_level && @ip_addr!=@ip_nil && @widget.blinking? 
      @widget.stop_blink 
    end
  end
  
  def ip_addr(_interface=self.conf('interface'))
    res = @ip_nil
    open("|ifconfig #{_interface} | grep 'inet ' | awk  '{print $2}'","r"){|f|
       begin
         res = f.read.strip
         res = @ip_nil if res.length == 0
       rescue  Errno::EINVAL => e
         res = @ip_nil
       end   
    }
    res
  end
  
  def build_value_perc(_level)
    suf="@"
    suf+"%3d".%(_level)+' %'    
  end

  def build_value(_level)
    fchar="="
    lchar="-"
    lnorm = _level/10
    @ip_addr = ip_addr if @ip_addr.nil? || @ip_addr == @ip_nil
    "#{@ip_addr} #{fchar*lnorm}#{lchar*(10-lnorm)}"
  end

  def current_level
    res = 0
    begin
      signal = %x(sudo iw dev wlan0 link | grep 'signal' | awk '{printf "%s ", $2, $3}')
      signal.strip! if signal
      res = signal.to_i.abs
    rescue Error => e
      res=0 
    end 
    res
  end 

  def current_level_old
    res = 0
    #open("#{self.conf('info_dir')}/wireless/link","r"){|f|
    open("#{self.conf('info_dir')}/iflink","r"){|f|
       begin
         value = f.read
         res = value.strip.to_i
       rescue  Errno::EINVAL => e
         res = 0
       end   
    }
    res
  end

end