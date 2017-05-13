---
title: SprigBean的创建顺序
date: 2017-05-13 12:36:29
tags:
---
# 在Spring boot中我们通过@Bean或者@Component或者@Service注解来创建Bean，那么创建的顺序是什么呢？
## Case1
  一个A类实现了某个接口，而另外一个类B又实现了该类A，同时还有一个类C，那么在A和B中都有@Bean C 和@Autowired C，  
  此时A和B不能同时用@Component注解，否则报错，代码如下,此时Controller 中使用TestInterface的对象是A，C 也是A中的@Bean创建的

```
@Component
public class A implements TestInterface {

    private String source;
    public A(String source){
        this.source = source;
    }
	@Autowired
	C c;
	@Override
	public String hello() {
		return c.hello2("a")+">>>bean create source="+ this.source;
	}
	
	@Bean
	C test(){
		return new C("A");
	}

}

```

```
@RestController
class TestRestController {
	
	@Autowired
	A a;

	@RequestMapping("hello")
	public Object hello(){
        return a.hello();
	}
}
```

问题：如果A不能满足要求了，需要对A进行扩展，此时有了B继承A，如果要使用B这时在SpringBoot的启动文件中加入@Bean B的创建
那么此时的C就不再是A中创建了,A 中的C就是B创建了，而且A中C的@Bean也不执行

```

public class B extends A {
    private String source;
    public B(String source){
        this.source = source;
    }
	@Autowired
	C c;
	@Override
	public String hello() {
		return c.hello2("b")+">>>bean create source="+ this.source;
	}
	
	@Bean
	C test(){
		return new C("B");
	}

}

```
  ```
@Bean
TestInterface b(){
    return new B();
}
```
## Case2
关于Bean的创建顺序，Bean的创建和被使用对象注入的顺序有关，同样用A B C 类为例,在Controller中注入了A和B，B在前面，
在启动时通过断点追踪会发现B中的@Bean C会执行，A中的不会执行，调用时通过断点可以看到A中C对象中的来源是B，
调换Controller中的A B顺序，会发现A中的@Bean C执行了，而B中的没有执行

```
@Component
public class A{

    private String source;
    public A(String source){
        this.source = source;
    }
	@Autowired
	C c;
	@Override
	public String hello() {
		return c.hello2("a")+">>>bean create source="+ this.source;
	}
	
	@Bean
	C test(){
		return new C("A");
	}

}

```
```
@Component
public class B {
    private String source;
    public B(String source){
        this.source = source;
    }
	@Autowired
	C c;
	@Override
	public String hello() {
		return c.hello2("b")+">>>bean create source="+ this.source;
	}
	
	@Bean
	C test(){
		return new C("B");
	}

}

```
```
@RestController
class TestRestController {
	
	@Autowired
	B b;
	@Autowired
	A a;

	@RequestMapping("hello")
	public Object hello(Integer flag,String topic,String key,String msg){

				a.hello();
				return b.hello();
	}
}
```

# 总结
Bean的创建时和Spring中对象的衣领关系相关联，注入的顺序靠前就先创建，如果是同一个实例和同一接口的实现的实例有注入最早的来创建Bean，靠后的不会再创建

# 附：Spring 中配置和属性文件的执行顺序

1. 命令行参数
2. 来自java:comp/env的JNDI属性
3. Java系统属性（System.getProperties()）
4. 操作系统环境变量
5. RandomValuePropertySource配置的random.*属性值
6. jar包外部的application-{profile}.properties或application.yml(带spring.profile)配置文件
7. jar包内部的application-{profile}.properties或application.yml(带spring.profile)配置文件
8. jar包外部的application.properties或application.yml(不带spring.profile)配置文件
9. jar包内部的application.properties或application.yml(不带spring.profile)配置文件
10. @Configuration注解类上的@PropertySource
11. 通过SpringApplication.setDefaultProperties指定的默认属性
