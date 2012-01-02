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
    num = check_mail
    if conf('format')
    	@widget.value = eval(conf('format'))
    else
    	@widget.value = "*** [#{num}] NEW MAIL ***"
    end
    if num >= 1
      show_widget(@widget)
      refresh_widget(@widget)
      @widget.start_blink if !@widget.blinking?
    elsif num == 0 && @widget.visible
      @widget.stop_blink if @widget.blinking?
      hide_widget(@widget) 
    end
    @last_num = num
  end

  def check_mail
    res = 0
    open(%Q{|chk4mail #{File.expand_path(conf('mbox'))} |awk '{print $2}'},"r"){|f|
       res = f.read.strip.to_i
    }
    res
  end

end