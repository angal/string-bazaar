#
#   timedate.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

class Timedate < StringStall

  def build
    attach_task(1,self,:update)
    @widget = add_widget(StringWidget.new(@name))
  end
 
  def update
    t = Time.now
    @widget.value = t.strftime("#{conf('format')}") 
    refresh_widget(@widget)
  end
  
end