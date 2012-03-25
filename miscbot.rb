#!/usr/bin/env ruby

require 'cgi'
require 'cinch'
require 'cinch/plugins/basic_ctcp'
require 'digest/md5'
require 'open-uri'
require 'tzinfo'
require 'urbanterror'

bot = Cinch::Bot.new do
  configure do |c|
    c.nick = 'miscbot'
    c.server = 'irc.tenthbit.net'
    c.port = 6667
    c.channels = ['#offtopic', '#bots', '#flood']

    c.plugins.plugins = [Cinch::Plugins::BasicCTCP]
    c.plugins.options[Cinch::Plugins::BasicCTCP][:commands] = [:version, :time, :ping]

    @last_question = {}
    @memes = []
  end

  on :message, /^!urt (.+)/ do |m, server|
    begin
      Timeout::timeout 5 do
        # Split the server:port and do some magic.
        port = server.split(':')
        server = port[0]
        port = port.size > 1 ? port.to_i : 27960
        urt = UrbanTerror.new(server, port)
        settings = urt.settings
        players = urt.players.sort_by { |player| -player[:score] }
        playersinfo = []
        if players.count != 0
          players.each do |player|
            player[:name] = "#{3.chr}04#{player[:name]}#{3.chr}" if player[:ping] == 999
            playersinfo << "#{player[:name].gsub(/ +/, ' ')} (#{player[:score]})"
          end
          players = "Players: #{playersinfo.join(', ')}"
        else
          players = "No players."
        end
        weapons = UrbanTerror.reverseGearCalc(settings['g_gear'].to_i)
        weapons = case weapons.size
                  when 0
                    'knives'
                  when 7
                    'all weapons'
                  else
                    weapons.join(', ')
                  end
        gametype = UrbanTerror.matchType(settings['g_gametype'].to_i, true)
        m.reply("Map: #{2.chr}#{settings['mapname']}#{2.chr} (#{gametype} w/ #{weapons}). #{players}")
      end
    rescue Timeout::Error
      m.reply("Timeout occurred.")
    rescue => error
      m.reply("[ERROR] #{error.message} (check your syntax and try again).")
    end
  end

  on :message, /^!gear (.+)/ do |m, gear|
    begin
      if gear =~ /^-?\d+$/
        weapons = UrbanTerror.reverseGearCalc(gear.to_i).join(', ')
        m.reply("#{weapons}")
      else
        number = UrbanTerror.gearCalc(gear.gsub(' ','').split(','))
        m.reply("#{number}")
      end
    rescue => error
      m.reply("#{error.message}")
    end
  end

  on :message, /^`meep$/ do |m|
    m.reply('meep')
  end

  on :message, /^!lcalc (\S+) (\S+)$/ do |m, a, b|
    aa = Digest::MD5.hexdigest(a).to_i(16)
    bb = Digest::MD5.hexdigest(b).to_i(16)
    m.reply("Love match for #{a} and #{b}: #{(aa + bb) % 100}%", true)
  end

  on :message, /^!flip$/ do |m|
    m.reply(['Heads', 'Tails'].sample, true)
  end

  on :message, /^!(\d+)?d(\d+)$/ do |m, dice, sides|
    dice, sides = dice.to_i, sides.to_i
    if dice < 2
      m.reply(rand(sides) + 1, true)
    else
      rolls = Array.new(dice) {rand(sides) + 1}
      if dice > 100
        m.reply("#{rolls.reduce(:+)}", true)
      else
        m.reply("#{rolls.join(' + ')} = #{rolls.reduce(:+)}", true)
      end
    end
  end

  on :message, /^(!automeme|!meme) ?(.+)?/ do |m, _, target|
    @memes = open('http://api.automeme.net/text').read.split("\n") if @memes == []
    m.reply(target ? "#{target}: #{@memes.shift}" : @memes.shift)
  end

  on :message, /^!lmgtfy$/ do |m|
    return unless @last_question[m.channel]
    words = @last_question[m.channel].message.split(' ')
    words = words[1..-1] if words[0].include?(':')
    message = words.join(' ')
    @last_question[m.channel].reply("http://lmgtfy.com/?q=#{CGI.escape(message)}", true)
  end

  on :message, /^!time (.+)/ do |m, timezone|
    begin
      tz = TZInfo::Timezone.get(timezone.gsub(' ', '_'))
    rescue TZInfo::InvalidTimezoneIdentifier
      m.reply('Invalid timezone', true)
    end
    m.reply(tz.now.asctime)
  end

  on :message, /\?$/ do |m|
    @last_question[m.channel] = m
  end
end

bot.start
