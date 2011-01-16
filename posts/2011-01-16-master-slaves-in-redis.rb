### Synopsis

# __Replication__ _(taken from Wikipedia)_ - the process of sharing information so as to ensure consistency between redundant resources, such as software or hardware components, to improve reliability, fault-tolerance, or accessibility.
#
#### Why is this important?
# 
# 1. __Scaling reads.__ If your application is read-heavy, this is the easiest
#    and most efficient way of scaling your web application.
# 2. __Backups.__ Replication by nature backs up data from a master server
#   to one or more slaves. Coupled with automated backups, you can setup a 
#   robust yet maintainable fault-tolerant solution for your application.
#
#### Redis Replication?
#
# The good news is that it is very easy to do replication with redis. Off the
# top of my head these are the only steps you need to do to setup replication:
#
# 1. Run the master
# 2. Write a configuration for a slave. Mark it as a slave of your master using
#    the `slaveof` directive (see [redis.conf][slaveof]).
# 3. Run `redis-server /path/to/slave.conf`. Done!
<<-EOT


         _____   ______  _____   _       _____ 
        |  __ \ |  ____||  __ \ | |     |_   _|
        | |__) || |__   | |__) || |       | |  
        |  _  / |  __|  |  ___/ | |       | |  
        | | \ \ | |____ | |     | |____  _| |_ 
        |_|  \_\|______||_|     |______||_____|
        
          _____         _______  _____  ____   _   _ 
         / ____|    /\ |__   __||_   _|/ __ \ | \ | |
        | |        /  \   | |     | | | |  | ||  \| |
        | |       / /\ \  | |     | | | |  | || . ` |
        | |____  / ____ \ | |    _| |_| |__| || |\  |
         \_____|/_/    \_\|_|   |_____|\____/ |_| \_|


EOT

#### What about the application level?

# In an ideal world, everything happens magically. This is primarily the
# reason why so many NoSQL solutions attempt transparent sharding and
# replication, because application developers want to remove the
# implementation details of the storage as much as possible from the
# actual appliction domain logic, because once you mix the two, you probably
# are going to make a huge mess (eventually).
#
# Given that, I also attempted the transparent __"just works"__ solution,
# which can easily be described by the block of code on the right:
#
begin
  require "redis"
  require "redis/replicated"

  r = Redis::Replicated.new(["redis://127.0.0.1:6379", 
                             "redis://127.0.0.1:6380"])

  r.set("foo", "bar") # Writes to 6379
  r.get("foo")        # Fetches from 6380
rescue LoadError, Exception
  puts "Of course this won't work yet right? :-)"
end

# [redis]: http://redis.io
# [ohm]: http://ohm.keyvalue.org
# [slaveof]: https://github.com/antirez/redis/blob/master/redis.conf#L107-L134
#

#### Let the transparent magic solution, begin!

# _Let's take a look at my 68 LOC solution for this. This was a prototype, mind
# you, so much of this is still a draft and should not be used in a production
# environment._

# Following the convention of adding plugins and extensions to existing
# Ruby gems, let's quickly add the class `Replicated` to the `Redis`
# class which is defined by the `redis-rb` gem.
class Redis
  class Replicated
    # We define the API of the constructor to accept an array of
    # URIs which look like:
    #
    #     ["redis://127.0.0.1:6379", "redis://127.0.0.1:6380", ...]
    def initialize(servers = [])
      @master_url = servers[0]
      @slave_urls = servers[1..-1]
    end
  
    # For simplicity, we will assume that the first server on the list
    # is the master server.
    def master
      @master ||= Redis.connect(:url => @master_url)
    end
  
    # Also to attain our prototype faster, we jump straight to the bare
    # assumption that we only have 1 slave server.
    def slave
      @slave ||= Redis.connect(:url => @slave_urls.first)
    end
  
    # This is probably the only command we'll need to manually define.
    # Basically selecting `db: 0` should happen both on the master and
    # slave side.
    def select(db)
      master.select(db)
      slave.select(db)
    end
  
    # Ok now follows the "boy scout" work. Basically we list down
    # all commands that actually write (or at least depend on happening
    # on the master server). They aren't that many actually.
    WRITE_METHODS = [:append, :blpop, :brpop, :brpoplpush, :decr, :decrby,
      :del, :discard, :expire, :expireat, :getset, :hdel, :hincrby, :hmset,
      :hset, :hsetnx, :incr, :incrby, :linsert, :lpop, :lpush, :lpushx, :lrem,
      :lset, :ltrim, :move, :mset, :msetnx, :persist, :psubscribe, :publish,
      :punsubscribe, :rename, :renamenx, :rpop, :rpoplpush, :rpush, :rpushx,
      :sadd, :sdiffstore, :set, :setbit, :setex, :setnx, :setrange,
      :sinterstore, :smove, :spop, :srem, :subscribe, :sunionstore,
      :unsubscribe, :watch, :unwatch, :zadd, :zincrby, :zinterstore, :zrem,
      :zremrangebyrank, :zremrangebyscore, :zunionstore, :[]=, :mapped_mset,
      :mapped_msetnx, :mapped_hmset, :keys, :randomkey, :multi, :pipelined]
  
    # Now we list the remaining commands as read commands.
    READ_METHODS  = [:exists, :get, :hexists, :hget, :hgetall, :hkeys, :hlen,
      :hmget, :hvals, :lindex, :llen, :lrange, :scard, :sdiff, :sinter,
      :sismember, :smembers, :sort, :srandmember, :strlen, :substr, :sunion,
      :ttl, :type, :zcard, :zcount, :zrange, :zrangebyscore, :zrank,
      :zrevrange, :zrevrank, :zscore, :[], :mget, :mapped_mget, :mapped_hmget,
      :dbsize]
  
    # Now let's quickly loop through all the write commands and define
    # them one by one. Let's just make sure to pass them along to the master.
    WRITE_METHODS.each do |meth|
      define_method meth do |*args, &bk|
        master.send(meth, *args, &bk)
      end
    end
  
    # Next we pass up all read commands to the slave.
    READ_METHODS.each do |meth|
      define_method meth do |*args, &bk|
        slave.send(meth, *args, &bk)
      end
    end
  end
end

#### Test drive time

# Let's quickly setup a replicated [Redis][redis] environment on our
# machine. For our purposes here, I'll assume you already have `redis-server`
# available.
#
# So follow the following steps:
#
# 1. Type `redis-server` on a terminal window.
# 2. Download the [redis.conf][slaveof] file. Change the slaveof directive
#    to point to 127.0.0.1 6379 instead.
# 3. Run `redis-server path/to/slave.conf` (wherever you downloaded the 
#    `redis.conf` file).
# 4. If you haven't done so already, install redis-rb via `gem install redis`.
# 5. Also let's use the `cutest` gem, by simply doing `gem install cutest`.

require "redis"
require "cutest"

r = Redis::Replicated.new(["redis://127.0.0.1:6379", "redis://127.0.0.1:6380"])
r.set("foo", "bar")
assert r.get("foo") == "bar"

slave = Redis.connect(url: "redis://127.0.0.1:6380") 
assert slave.get("foo") == "bar"

r.del("foo")
assert r.exists("foo") == false
assert slave.exists("foo") == false

#### So far so good?
#
# Of course it works for our super simple fabricated example, but what happens
# when you try this out in a test-suite of a fairly large enough application?
#
# To cut to the chase I'll just summarize the problems with the current
# solution:
#
# 1. There might be cases where there is replication lag. If your application
#    cannot tolerate inconsistency, then this is a huge loss.
# 2. If you're the type of person who is an absolute control freak,
#    then this solution might not be for you.
# 3. Effectively we get occassional inconsistency errors when we try and run 
#    this against a real-world application.

#### Wrap-up
#
# I've actually created a repo for this, but personally I am a control
# freak, and I'm not completely happy with the results of this solution.
# 
# If you are however interested, head out to 
# [the repo](http://github.com/cyx/redis-replicated). Your comments, suggestions,
# and/or violent reactions are much appreciated.
