# found on http://www.jbrowse.com/text/generator.shtml

require "forwardable"

# extend array with convenient methods
class Array
  def indexof(v)
    self.index(v) || -1
  end

  def shuffle!
    tmp=[]
    while self.size > 0 do
      r = (rand*self.size).to_i
      tmp[tmp.size] = self[r]
      self.delete_at(r)
    end
    tmp.each { |n| self[self.size]=n }
  end

  def at_random
    self[(rand*self.size).to_i]
  end

  def append(x)
    self[self.size]=x
  end
end




#atoms may have semantic information
class Atom
  extend Forwardable 

  attr_accessor  :semantics, :value, :section
  # pass method calls to semantics
  def_delegators :@semantics, :apply, :score
  
  
  def initialize(c, s)
    @section = c
    @semantics = Semantics.new
    s.split.each do |t|
      case t
        when /^\{(.*)\}/
          @semantics.apply($1)
        else
          @value ? @value += " " + t : @value = t 
        end
    end
  end

  def to_s
    @value
  end
end


#rules may have predicates
class Rule
  attr_accessor :section, :tokens

  def initialize(c, s)
    @section = c
    @tokens = s.split
  end

  def each (&pr)
    @tokens.each{|t| yield t}
  end

  def to_s
    @tokens.to_s
  end
end

#the state contains information that is used to pick atoms
class Semantics
  attr_accessor :flags

  def initialize
    reset
  end

  def set(s, f)
    case s
    when "+"
      @flags[f] = 1
    when "-"
      @flags[f] = -1
    when "!"
      @flags[f] = 0
    when "~"
      @flags[f] = @flags[f]*-1 if @flags[f]
    else
      raise "State flag #{s} not understood."
    end
  end

  def reset
    @flags = Hash.new
  end

  def getFlag(f)
    @flags[f] ? @flags[f] : 0
  end

  def apply(s)
    s.split(",").each do |t|
      a = t.slice 0,1
      b = t.slice 1,1
      set(a,b)
    end
  end

  def merge(s)
    s.flags.each_pair do |f, v|
      @flags[f] = getFlag(f) + v
    end
  end

  #how well do these two values match?
  def score(s)
    score=0;
    @flags.each_pair do |f, v|
      x = s.getFlag(f)
      (x==v) ? score+=1 : score-=1;
    end
    score
  end

  def strict_score(s)
    score=0;
    @flags.each_pair do |f, v|
      x = s.getFlag(f)
      (x==v) ? score+=1 : score=-1000;
    end
    score
  end

  def easy_score(s)
    score=0;
    @flags.each_pair do |f, v|
      x = s.getFlag(f)
      (x==v) ? score+=1 : score+=0;
    end
    score
  end
end



#main class
class Cc

  attr_accessor :log, :atom, :rule, :state, :stickyatoms


  def initialize
    @atom = Hash.new
    @rule = Hash.new
    @state = Semantics.new
    @stickyatoms = true
    @log = false
  end

  #load rules and atoms
  def loadTables(file)
    f = File.open(file, "r")
    section = "unknown"
    what = Atom

    f.each_line do |l|
      l.chop!
      case l
      when ""
      when /^#/
      when /\[(.*)\]/
        section = $1
        what = Rule
        
        @rule[section] = Array.new unless @rule[section] 
      when /<(.*)>/
        what = Atom
        section = $1
        
        @atom[section] = Array.new unless @atom[section] 
      else
        x = what.new(section, l)
        what == Atom ?  @atom[section].append(x) : @rule[section].append(x)
        
        p x if @log
      end
    end
  end

  #given a rule name, expand it recursively
  def dorule(rulename)
    p "Rule: " + rulename if @log
    s=""
    a = @rule[rulename]
    raise "Rule #{rulename} does not exist" if a==nil
    rule = a.at_random

    begin
      rule.each do |tok|
        case tok
        when /^_(.*)/
          r = doatom($1)
        when /^%(.*)/
          r = dorule($1)
        when /^\{(.*)\}/
          dopred($1)
          r = ""
        else
          r = tok
        end

        s += r.to_s
        s += " "
      end

    rescue
      p "Error in rule " + rule.to_s
      raise
    end
    p "Value: " + s if @log
    s
  end

  #given a string which is a semantic predicate embedded in a rule... do something great!
  def dopred(pred)
    p "Evaluating semantic predicate: " + pred if @log
    begin
      @state.apply(pred)
    rescue
      p "Error in predicate " + pred
      raise
    end
  end

  #given an atom type, pick an atom
  def doatom(atomname)
    best = nil
    a = @atom[atomname]
    atom=nil
    raise "Atom #{atom} does not exist" if a == nil
    bestscore = -1000000
    (0..16).each do |i|
      atom = a.at_random
      score = @state.score(atom.semantics)
      if bestscore < score then
        bestscore = score
        best = atom
        # p "best match " + score.to_s + "  " + atom.to_s
      end
    end

    if @stickyatoms then
      @state.merge(atom.semantics)
      # p @state
    end

    best.to_s
  end


  #given the string result of a rule or literal, apply it to outputstring
  def postProcess(s)
    out = ""
    nospace = true
    sentencebreak = true
    waitingfora = false

    a = s.split
    a.each do |t|
      case t
      when "`"
        nospace = true
      when "&"
        out += "\n" if sentencebreak
        sentencebreak = true
      when "@"
        waitingfora = true
      else
        out += " " unless nospace == true
        out += "\n" if sentencebreak == true

        if waitingfora then
          x = t.slice(0,1)
          if x=="a" || x=="e" || x=="i" || x=="o" || x=="u" then
            t = "an " + t
          else
            t = "a " + t
          end
        end

        t = "I" if t == "i"


        t.capitalize! if sentencebreak == true
        out += t

        nospace = false
        sentencebreak = false
        waitingfora = false
      end
    end

    out
  end
end

cc = Cc.new
cc.loadTables("./ctab.txt")
cc.log = false # 

hp = cc.dorule('description') ; puts cc.postProcess(hp)
