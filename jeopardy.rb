require 'json'
require 'socket'

class Jeopardy
  def update_remaining()
    @c.each do |c|
      count = 0
      c[:questions].each do |q|
        if(!q[:answered])
          count = count + 1
        end
      end

      c[:remaining] = count
    end
  end

  def init_categories(file)
    File.open(file) do |q|
      @c = JSON.load(q)
    end

    @c.each do |c|
      c[:name] = c["name"]
      c[:questions] = c["questions"]
      c.delete("name")
      c.delete("questions")

      c[:questions].each do |q|
        q[:question] = q["question"]
        q[:answer] = q["answer"]
        q.delete("question")
        q.delete("answer")
        q[:answered] = false
      end
    end

    update_remaining()
  end

  def initialize(question_file)
    init_categories(question_file)

    @players = {}
    @watchers = []

    puts("Starting server on 0.0.0.0:5555, tell users to connect to it with telnet or netcat or whatever!")
    server = TCPServer.new("0.0.0.0", 5555)

    Thread.start do
      begin
        loop do
          Thread.start(server.accept) do |s|
            puts("Received a new connection!")
            begin
              s.puts("Who are you? (Just hit [enter] if you aren't playing)")
              s.puts("Users already in the game:")
              @players.each do |p|
                s.puts("--> #{p}")
              end

              name = s.gets()
              if(!name.nil?)
                name = name.chomp
                if(name == "")
                  @watchers << s
                  puts("A new watcher has connected")
                  s.puts("Welcome, watcher!")
                else
                  if(@players[name].nil?)
                    @players[name] = { :socket => s, :score => 0 }
                    puts("A new player has connected: #{name}")
                    s.puts("Welcome, #{name}!")
                  else
                    @players[name][:socket] = s
                    puts("#{name} has re-joined!")
                    s.puts("Welcome back, #{name}!")
                  end
                end
              end
            rescue Exception => e
              puts(e)
            end
          end
        end
      rescue Exception => e
        puts(e)
      end
    end
  end

  def show_board()
    names = []
    names << (@c[0][:remaining] > 0 ? @c[0][:name] : "")
    names << (@c[1][:remaining] > 0 ? @c[1][:name] : "")
    names << (@c[2][:remaining] > 0 ? @c[2][:name] : "")
    names << (@c[3][:remaining] > 0 ? @c[3][:name] : "")
    names << (@c[4][:remaining] > 0 ? @c[4][:name] : "")
    names << (@c[5][:remaining] > 0 ? @c[5][:name] : "")

    max_length = 0
    0.upto(names.length - 1) do |i|
      names[i] = names[i].split(/ /)
      max_length = [max_length, names[i].length].max
    end

    print_all("\n" * 100)
    print_all("+------------+------------+------------+------------+------------+------------+\n")
    print_all("|            |            |            |            |            |            |\n")
    0.upto(max_length - 1) do |i|
      names[0][i] = names[0][i].nil? ? "" : names[0][i]
      names[1][i] = names[1][i].nil? ? "" : names[1][i]
      names[2][i] = names[2][i].nil? ? "" : names[2][i]
      names[3][i] = names[3][i].nil? ? "" : names[3][i]
      names[4][i] = names[4][i].nil? ? "" : names[4][i]
      names[5][i] = names[5][i].nil? ? "" : names[5][i]
      print_all("| %s | %s | %s | %s | %s | %s |\n" % [ names[0][i].center(10), names[1][i].center(10), names[2][i].center(10), names[3][i].center(10), names[4][i].center(10), names[5][i].center(10)])
    end
    print_all("|            |            |            |            |            |            |\n")
    print_all("+------------+------------+------------+------------+------------+------------+\n")

    0.upto(4) do |i|
      points = []
      points[0] = (@c[0][:questions][i][:answered] ? "" : "$%d" % ((i + 1) * 100))
      points[1] = (@c[1][:questions][i][:answered] ? "" : "$%d" % ((i + 1) * 100))
      points[2] = (@c[2][:questions][i][:answered] ? "" : "$%d" % ((i + 1) * 100))
      points[3] = (@c[3][:questions][i][:answered] ? "" : "$%d" % ((i + 1) * 100))
      points[4] = (@c[4][:questions][i][:answered] ? "" : "$%d" % ((i + 1) * 100))
      points[5] = (@c[5][:questions][i][:answered] ? "" : "$%d" % ((i + 1) * 100))

      print_all("| %s | %s | %s | %s | %s | %s |\n" % [ points[0].center(10), points[1].center(10), points[2].center(10), points[3].center(10), points[4].center(10), points[5].center(10)])
      print_all("+------------+------------+------------+------------+------------+------------+\n")
    end

    # For the console
    puts()
    i = 0
    @c.each do |c|
      i += 1
      name = c[:name]
      points = []
      points[0] = (c[:questions][0][:answered] ? "    " : "$100")
      points[1] = (c[:questions][1][:answered] ? "    " : "$200")
      points[2] = (c[:questions][2][:answered] ? "    " : "$300")
      points[3] = (c[:questions][3][:answered] ? "    " : "$400")
      points[4] = (c[:questions][4][:answered] ? "    " : "$500")

      puts("%d %s %s %s %s %s %s" % [i, name.ljust(28), points[0], points[1], points[2], points[3], points[4], points[5]])
    end
    puts()

    @players.each_pair do |name, keys|
      puts_all("#{name}: $#{keys[:score]}")
      puts("#{name}: $#{keys[:score]}")
    end
  end

  def puts_all(str)
    @players.each_pair do |name, p|
      begin
        p[:socket].puts(str)
      rescue Exception => e
        puts("ERROR: #{e}")
      end
    end

    @watchers.each do |w|
      begin
        w.puts(str)
      rescue Exception => e
        puts("ERROR: #{e}")
      end
    end
  end

  def print_all(str)
    @players.each_pair do |name, p|
      begin
        p[:socket].print(str)
      rescue Exception => e
        puts("ERROR: #{e}")
      end
    end

    @watchers.each do |w|
      begin
        w.print(str)
      rescue Exception => e
        puts("ERROR: #{e}")
      end
    end
  end

  def clear_buffers(sockets)
    loop do
      result = IO.select(sockets, nil, nil, 0.25)
      if(result.nil?)
        break
      end
      result[0][0].gets()
    end
  end

  def go()
    message = nil

    loop do
      show_board()

      if(!message.nil?)
        puts(message)
        message = nil
      end

      command = $stdin.gets().chomp

      command, params = command.split(/ /, 2)

      if(command == "ask" || command == "a")
        params = params.split(/ /, 2)
        category = (params[0].to_i - 1)
        question = ((params[1].to_i / 100) - 1)

        if(@c[category].nil? || @c[category][:questions][question].nil?)
          message = "Invalid category or question!"
          next
        end

        cat = @c[category][:name]
        q   = @c[category][:questions][question][:question]
        a   = @c[category][:questions][question][:answer]

        # Create a list of player sockets for select() to wait on
        sockets = [$stdin]
        @players.each_value do |p|
          sockets << p[:socket]
        end

        done = false
        while(!done)do
          # Display the question and answer to the host
          puts()
          puts()
          puts("#{cat} for $#{((question + 1) * 100)}...")
          puts()
          puts("Question >>> #{q}")
          puts("Answer >>> #{a}")
          puts()
          puts("(press <enter> to time out)")

          # Display just the question to the contestants
          puts_all("#{cat} for $#{((question + 1) * 100)}...")
          puts_all("")
          puts_all("#{q}")
          puts_all("")
          puts_all("Press <enter> to answer the question!")

          # Wait for somebody to send data
          begin
            # By clearing buffers first, people can't hit 'enter' earlier and get in fast
            clear_buffers(sockets)
            result = IO.select(sockets)
          rescue Exception => e
            puts("Error in select(): #{e}")
            next
          end

          if(result[0][0] == $stdin || result[0][0] == $stdout)
            puts_all("Out of time!")
            done = true
          else
            buzzer = result[0][0]

            found = false
            @players.each_pair do |name, player|
              if(player[:socket] == buzzer)
                found = true

                puts("#{name} buzzed!")
                puts()
                puts("Were they right (y/n)?")

                result = $stdin.gets().chomp
                if(result[0] == "y")
                  player[:score] += ((question + 1) * 100)
                  done = true
                elsif(result[0] == "n")
                  player[:score] -= ((question + 1) * 100)
                end
              end
            end

            if(!found)
              puts("ERROR: Couldn't figure out who buzzed! #{buzzer.inspect}")
            end
          end
        end

        clear_buffers(sockets)

        @c[category][:questions][question][:answered] = true
      elsif(command == "list")
        @players.each do |p|
          puts(p)
        end
      else
        puts("Unknown command: #{command.inspect}")
      end
    end
  end
end

if(ARGV.length > 0)
  j = Jeopardy.new(ARGV[0])
else
  j = Jeopardy.new("./practice.json")
end
j.go()
