#
#   cmdout.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

class Cmdout < StringStall
  
  def update
    @widget.value = "#{conf('label')}#{self.cmdoutput}" 
    refresh_widget(@widget)
  end
  
  def cmdoutput
    ret = ""
    open("|#{conf('cmd')}","r"){|f|
      ret = f.read.strip
    }
    ret
  end  
end