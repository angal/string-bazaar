#
#   wall.rb - string-bazaar
#   by Antonio Galeone <antonio.galeone@gmail.org>
#

class Wall < StringStall

  def build
    if conf('type')=='random'
      attach_task(conf('random.gap').to_i,self,:update)
      update
    end
  end

  def check
    if conf('type')
      File.exists?(File.expand_path(conf('dir')))
    else
      false
    end
  end

  def update
    system_send("feh --bg-center #{random_file}")
  end

  def random_file
    files = Array.new
    files = Dir["#{File.expand_path(conf('dir'))}/*"].sort
    files.delete_if {|f| File.stat(f).directory?}
    selected_file = files[rand(files.length)]
    selected_file
  end

end
