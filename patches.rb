class Enumerator
  def next_or_nil
    self.next
  rescue StopIteration
    nil
  end
end

class Range
  def &(other)
    ([first, other.first].max...[last, other.last].min)
  end

  def |(other)
    ([first, other.first].min...[last, other.last].max)
  end
end
