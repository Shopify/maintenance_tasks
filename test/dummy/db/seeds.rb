# frozen_string_literal: true
10.times do |i|
  Post.create!(title: "Post ##{i}", content: "Content ##{i}")
end
