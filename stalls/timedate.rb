#
#   timedate.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

class Timedate < StringStall

  def update
    t = Time.now
    @widget.value = t.strftime("#{conf('format')}") 
    #conf('i3bar.color', '#ffffff')
    refresh_widget(@widget) 
  end
  
end