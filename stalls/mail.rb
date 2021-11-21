#
#   mail.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#


class Mail < StringStall
  def build
    attach_task(30,self,:update)
    @widget = add_widget(StringWidget.new(self))
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
    open(%q{|echo "x" |mail | grep "^>N\|^>U\|^ N\|^ U"|wc -l},"r"){|f|
       res = f.read.strip.to_i
    }
    res
  end

  def last_from
    res = ""
    open(%q{|echo "x" |echo "x" |mail | grep "^>N\|^>U"|awk '{print $2}'},"r"){|f|
       res = f.read.strip
    }
    res
  end	  

end