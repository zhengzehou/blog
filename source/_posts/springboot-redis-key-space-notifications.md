---
title: springboot-redis key到期事件通知（消息订阅发布）
date: 2017-06-01 10:15:07
tags:
---
  Redis的键空间通知(keyspace notifications)功能是自2.8.0版本开始加入的，客户端可以通过订阅/发布(Pub/Sub)机制，接收那些以某种方式改变了Redis数据空间的事件通知。  
  通知是通过Redis的订阅/发布机制发送的，因此，所有支持订阅/发布功能的客户端都可在无需调整的情况下，使用键空间通知功能。  
   Redis的发布/订阅目前是即发即弃(fire and forget)模式的，因此无法实现事件的可靠通知。也就是说，如果发布/订阅的客户端断链之后又重连，则在客户端断链期间的所有事件都丢失了。 
   未来计划支持事件的可靠通知，但是这可能会通过让订阅与发布功能本身变得更可靠来实现，也可能会在Lua脚本中对消息的订阅与发布进行监听，从而实现类似将事件推入到列表这样的操作。
   <!-- more -->
# Key过期事件的Redis配置
因键空间通知功能需要耗费一定的CPU时间，因此默认情况下，该功能是关闭的。可以通过修改配置文件redis.conf，或者通过CONFIG SET命令，设置notify-keyspace-events选项，来启用或关闭该功能。
该选项的值为空字符串时，该功能禁用，选项值为非空字符串时，启用该功能，非空字符串由特定的多个字符组成，每个字符表示不同的意义：
         K：keyspace事件，事件以__keyspace@<db>__为前缀进行发布；
         E：keyevent事件，事件以__keyevent@<db>__为前缀进行发布；
         g：一般性的，非特定类型的命令，比如del，expire，rename等；
         $：字符串特定命令；
         l：列表特定命令；
         s：集合特定命令；
         h：哈希特定命令；
         z：有序集合特定命令；
         x：过期事件，当某个键过期并删除时会产生该事件；
         e：驱逐事件，当某个键因maxmemore策略而被删除时，产生该事件；
         A：g$lshzxe的别名，因此”AKE”意味着所有事件。
        这里需要配置 notify-keyspace-events 的参数为 “Ex”。x 代表了过期事件。notify-keyspace-events "Ex" 保存配置后，重启Redis服务，使配置生效。
# expired事件通知的发送时间
Redis 使用以下两种方式删除过期的键：
         a：当一个键被访问时，程序会对这个键进行检查，如果键已过期，则删除该键；
         b：系统会在后台定期扫描并删除那些过期的键；
         当过期键被以上两种方式中的任意一种发现并且删除时，才会产生expired事件通知。
         Redis不保证生存时间（TTL）变为 0 的键会立即被删除：如果没有命令访问这个键，或者设置生存时间的键非常多的话，那么在键的生存时间变为0，到该键真正被删除，这中间可能会有一段比较显著的时间间隔。
         因此，Redis产生expired事件通知的时间，是过期键被删除的时候，而不是键的生存时间变为 0 的时候。
# 客户端验证 Publish / Subscribe 
1. 进入redis的home目录，`redis-server reids.conf` 启动Redis，如果配置文件没有开启键值空间配置，可以通过 `config set notify-keyspace-events KEA `设置
2. 进入客户端命令 `redis-cli -h 127.0.0.1 -p 6379`
3. 订阅过期键值消息事件
```
127.0.0.1:6379> psubscribe __keyevent@0__:expired
Reading messages... (press Ctrl-C to quit)
1) "psubscribe"
2) "__keyevent@0__:expired"
3) (integer) 1
```
4. 再开启一个终端，redis-cli 进入 redis，新增一个 10秒过期的键：
```
127.0.0.1:6379> set testkey 123456 EX 10
OK
```
5. 观察另一个客户端，10s后的结果
```
127.0.0.1:6379> psubscribe __keyevent@0__:expired
Reading messages... (press Ctrl-C to quit)
1) "psubscribe"
2) "__keyevent@0__:expired"
3) (integer) 1
1) "pmessage"
2) "__keyevent@0__:expired"
3) "__keyevent@0__:expired"
4) "testkey"
```
# srping boot redis配置
## jar包依赖
```
    <dependency>
	   		<groupId>org.springframework.boot</groupId>
		    <artifactId>spring-boot-starter-redis</artifactId>
		    <version>1.4.6.RELEASE</version>
	   </dependency>
	   <dependency>
		    <groupId>org.springframework.session</groupId>
		    <artifactId>spring-session</artifactId>
		</dependency>
		<dependency>
		    <groupId>org.springframework.session</groupId>
		    <artifactId>spring-session-data-redis</artifactId>
		</dependency>
```
## 配置文件
```
spring:
    session:
    #使用了spring-session的缓存jar包，如果不配置store-type: none 启动报错
      store-type: none 
    redis: 
      database: 0
      host: 127.0.0.1
      port: 6379
      password: 
      pool.max-active: 8
      pool.max-wait: -1
      pool.max-idle: 8
      pool.min-idle: 0
      timeout: 0
    task:
      pool:
        corePoolSize: 10
        maxPoolSize: 20
        keepAliveSeconds: 60
        queueCapacity: 100
        threadNamePrefix: myThreadPool
        topic: __keyevent@0__:expired   
```
## Reis配置类
```
package com.ule.wholesale.fxpurchase.web.redis;

import java.lang.reflect.Method;


import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.CachingConfigurerSupport;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.serializer.Jackson2JsonRedisSerializer;
import org.springframework.cache.interceptor.KeyGenerator;
import com.fasterxml.jackson.annotation.JsonAutoDetect;
import com.fasterxml.jackson.annotation.PropertyAccessor;
import com.fasterxml.jackson.databind.ObjectMapper;

@Configuration
@EnableCaching
public class RedisConfig extends CachingConfigurerSupport {

	@Bean
    public org.springframework.cache.interceptor.KeyGenerator keyGenerator() {
        return new KeyGenerator() {
            @Override
            public Object generate(Object target, Method method, Object... params) {
                StringBuilder sb = new StringBuilder();
                sb.append(target.getClass().getName());
                sb.append(method.getName());
                for (Object obj : params) {
                    sb.append(obj.toString());
                }
                return sb.toString();
            }
        };
    }
	
	@SuppressWarnings("rawtypes")
    @Bean
    public CacheManager cacheManager(RedisTemplate redisTemplate) {
        RedisCacheManager rcm = new RedisCacheManager(redisTemplate);
        //设置缓存过期时间
        //rcm.setDefaultExpiration(60);//秒
        return rcm;
    }
	
	@Bean
    public RedisTemplate<String, String> redisTemplate(RedisConnectionFactory factory) {
        StringRedisTemplate template = new StringRedisTemplate(factory);
        Jackson2JsonRedisSerializer jackson2JsonRedisSerializer = new Jackson2JsonRedisSerializer(Object.class);
        ObjectMapper om = new ObjectMapper();
        om.setVisibility(PropertyAccessor.ALL, JsonAutoDetect.Visibility.ANY);
        om.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL);
        jackson2JsonRedisSerializer.setObjectMapper(om);
        template.setValueSerializer(jackson2JsonRedisSerializer);
        template.afterPropertiesSet();
        return template;
    }
}

```
## Redis设置key/value和get值
```
package com.ule.wholesale.fxpurchase.web.redis;

import java.util.concurrent.TimeUnit;

import javax.annotation.Resource;

import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.stereotype.Service;
@Service
public class RedisService {
	@Resource
	private RedisTemplate<String, Object> redisTemplate;
	public void set(String key, Object value) {
		ValueOperations<String, Object> vo = redisTemplate.opsForValue();
		vo.set(key, value);
	}
	/**
	 * 设置过期的key/value，过期时间单位为分钟
	 * @param key
	 * @param value
	 * @param mins
	 */
	public void set(String key, Object value,Integer mins) {
		ValueOperations<String, Object> vo = redisTemplate.opsForValue();
		vo.set(key, value, mins, TimeUnit.MINUTES);
	}

	public Object get(String key) {
		ValueOperations<String, Object> vo = redisTemplate.opsForValue();
		return vo.get(key);
	}
}
```
# Spring boot中实现过期事件监听
## 配置属性类 TaskThreadPoolConfig
```
package com.ule.wholesale.fxpurchase.web.redis;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix="spring.task.pool")
public class TaskThreadPoolConfig {

	private Integer corePoolSize;
	private Integer maxPoolSize;
	private Integer queueCapacity;
	private Integer keepAliveSeconds;
	private String threadNamePrefix;
	private String topic;
	
  set get ...
}

```
## 监听配置类
```
package com.ule.wholesale.fxpurchase.web.redis;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;

import javax.annotation.Resource;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
public class RedisMessageListenerContainerConfig {
	@Resource
	private RedisTemplate<String, Object> redisTemplate;
	
	@Autowired
	private TopicMessageListener messageListener;
	
	@Autowired
	private TaskThreadPoolConfig config;
	
	@Value("spring.redis.topic")
	private String topic;
	
	@Bean
	public RedisMessageListenerContainer configRedisMessageListenerContainer(Executor executor){
		RedisMessageListenerContainer container = new RedisMessageListenerContainer();
		// 设置Redis的连接工厂
		container.setConnectionFactory(redisTemplate.getConnectionFactory());
		// 设置监听使用的线程池
		container.setTaskExecutor(executor);
		// 设置监听的Topic
		ChannelTopic channelTopic = new ChannelTopic(config.getTopic());//"__keyevent@0__:expired");
		// 设置监听器
		container.addMessageListener(messageListener, channelTopic);
		return container;
	}
	
	@Bean // 配置线程池
	public Executor myTaskAsyncPool() {
		ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
		executor.setCorePoolSize(config.getCorePoolSize());
		executor.setMaxPoolSize(config.getMaxPoolSize());
		executor.setQueueCapacity(config.getQueueCapacity());
		executor.setKeepAliveSeconds(config.getKeepAliveSeconds());
		executor.setThreadNamePrefix(config.getThreadNamePrefix());

		// rejection-policy：当pool已经达到max size的时候，如何处理新任务
		// CALLER_RUNS：不在新线程中执行任务，而是由调用者所在的线程来执行
		executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
		executor.initialize();
		return executor;
	}
}
```
## 监听执行类
```
package com.ule.wholesale.fxpurchase.web.redis;

import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.stereotype.Component;

@Component
public class TopicMessageListener  implements MessageListener {

	@Override
	public void onMessage(Message message, byte[] pattern) {// 客户端监听订阅的topic，当有消息的时候，会触发该方法
        	byte[] body = message.getBody();// 请使用valueSerializer
        	byte[] channel = message.getChannel();
        	String topic = new String(channel);
        	String itemValue = new String(body);
        	// 请参考配置文件，本例中key，value的序列化方式均为string。
        	System.out.println("topic:"+topic);
        	System.out.println("itemValue:"+itemValue);
	}
}

```