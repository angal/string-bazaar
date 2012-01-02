#
#   chkmail.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#


class Chkmail < StringStall
  def build
    attach_task(30,self,:update)
    @widget = add_widget(WmiiWidget.new(@name))
    update
  end
  
  def update
    num = check_mail
    @widget.value = "N. mail = #{num}"
    if num >= 1
      @widget.value= "#{@widget.value} [last from #{last_from}]"  
    end
    refresh_widget(@widget)
  end

  def check_mail
    res = 0
    open(%Q{|chk4mail #{File.expand_path(conf('mbox'))} |awk '{print $2}'},"r"){|f|
       res = f.read.strip.to_i
    }
    res
  end

  def last_from
    res = ""
    open(%Q{|echo "x" |echo "x" |mail -f #{File.expand_path(conf('mbox'))} | grep "^>N\|^>U"|awk '{print $2}'},"r"){|f|
       res = f.read.strip
    }
    res
  end	  

end