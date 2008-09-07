# found on http://www.jbrowse.com/text/generator.shtml
require 'vig.rb'

cc = Cc.new
cc.loadTables("./ctab.txt")
cc.log = false # 

s = cc.dorule("epicpoem")
# print "\n\n-----\n\n"
print cc.postProcess(s)
# print "\n\n-----\n\n"


hp = cc.dorule('description') ; puts cc.postProcess(hp)

