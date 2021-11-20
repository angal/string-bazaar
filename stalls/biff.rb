#
#   biff.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#


class Biff < StringStall
  def build
    attach_task(30,self,:update)
    @widget = add_widget(StringWidget.new(@name))
    update
  end
  
  def update
    #num = check_mail
    check_mail
    if conf('format')
    	@widget.value = eval(conf('format'))
    else
    	@widget.value = "*** [#{@num}] NEW MAIL ***"
    end
    if @num >= 1 || (conf('format').include?('@tot') && @tot >= 1)
      show_widget(@widget)
      refresh_widget(@widget)
      @widget.start_blink if !@widget.blinking?
      if conf('on_new_action') && @num != @last_num
	 system(eval(conf('on_new_action')))	
      end
    elsif @num == 0 && @widget.visible
      @widget.stop_blink if @widget.blinking?
      hide_widget(@widget) 
    end
    @last_num = @num
  end

  def check_mail_old
    res = 0
    open(%Q{|chk4mail #{File.expand_path(conf('mbox'))} |awk '{print $2}'},"r"){|f|
       res = f.read.strip.to_i
    }
    res
  end
  
  def check_mail
    @num = 0
    @tot = 0
    open(%Q{|chk4mail #{File.expand_path(conf('mbox'))} |awk '{print $2 "|" $6}'},"r"){|f|
       str = f.read.strip
       a,b = str.split("|")
       if a && a.strip != '-'
	 @num = a.strip.to_i      
       end
       if b && b.strip != '-'
	 @tot = b.strip.to_i      
       end
    }
    
  end

end
