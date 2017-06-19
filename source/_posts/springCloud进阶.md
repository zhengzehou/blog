---
title: springCloud进阶
date: 2017-06-16 12:10:13
tags:
---
 前面介绍过，spring cloud项目是基于spring boot的，本篇文章是对spring boot和cloud常用配置进行简单提取、封装和约定，主要包括数据源配置、mybatis配置、常量、公共帮助类、consul的配置、公共过滤器等功能配置。公共配置将以jar包形式提供。如果有更好的封装和配置，将在后续文章中进行介绍。
<!--more-->
# 公共模块
## 在当前版本中，公共模块主要包括公共常量、业务中的枚举、数据源配置、SQLFilter、XssShellFilter（防止js、css注入）、常用util、Application父类
> 1. 公共常量在platfrom-properties.yml文件中进行配置在CommonConstants类中进行初始化，当前已有配置如下：
```
public static String uploadTempDir;
public static String uploadFileToDFSUrl;
public static String uploadFileUrl;
public static String globalStaticServer1;
public static String globalStaticServer2;
public static String globalStaticServer3;
public static String searchDistrIpPort;
```
> 2. 常量类的属性是通过 `@Value("${uploadTempDir}")`进行设置的，在springboot中@Value不支持静态变量的赋值，所以我们通过在set方法上添加`@Value("${uploadTempDir}")`可以实现

## 业务中的枚举对象，对应已经定义好的枚举值，并且需要多处使用的可以申请放到公共模块中
## 数据源配置，目前定义了单数据源的配置，包括mysql和oracle ,下面通过mysql进行说明 
> 1. 需要使用什么类型的数据源就在自己项目中的`MybatisConfiguration`配置类上通过`@Import({ DataBaseMysqlConfiguration.class })`导入需要的数据源
> 2. 数据源配置文件DataBaseMysqlConfiguration需要在自己项目中添加一个文件名为jdbc2.properties的配置文件内容如下：
```
jdbc.ule_uwds_selfsupport-master.url=jdbc:mysql://ip:3306/dbname?autoReconnect=true&autoReconnectForPools=true&useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull
jdbc.ule_uwds_selfsupport-master.username=username
jdbc.ule_uwds_selfsupport-master.password=***
jdbc.ule_uwds_selfsupport-master.initialSize=5
jdbc.ule_uwds_selfsupport-master.maxActive=5
jdbc.ule_uwds_selfsupport-master.maxIdle=5
jdbc.ule_uwds_selfsupport-master.minIdle=1
jdbc.ule_uwds_selfsupport-master.maxWait=6000
jdbc.ule_uwds_selfsupport-master.validationQuery=SELECT 1 
```
> 3. 以上配置会通过`JDBC2MysqlConfiguration`类读人配置的属性值并应用到数据源配置中,在`DataBaseMysqlConfiguration`类上面通过`@Import({JDBC2MysqlConfiguration.class})`来创建一个Bean，然后再使用，代码如下：
```
@PropertySource("classpath:jdbc2.properties")
@ConfigurationProperties(prefix="jdbc.ule_uwds_selfsupport-master")
public class JDBC2MysqlConfiguration {
	
	private String username;
	private String password;
	private String url;
	private Integer initialSize;
	private Integer maxActive;
	private Integer maxIdle;
	private Integer minIdle;
	private Integer maxWait;
	private String validationQuery;
```
> 4. JDBC2MysqlConfiguration的代码如下：
```
@Import({JDBC2MysqlConfiguration.class})
public class DataBaseMysqlConfiguration implements EnvironmentAware {

	private static Log log = LogFactory.getLog(DataBaseMysqlConfiguration.class);
	private RelaxedPropertyResolver propertyResolver;  
    @Autowired
    JDBC2MysqlConfiguration jdbc;
	@Override
	public void setEnvironment(Environment env) {
		this.propertyResolver = new RelaxedPropertyResolver(env, "spring.datasource.");
	}

	@Bean(name="dataSource", destroyMethod = "close", initMethod="init")  
    @Primary  
    public DataSource dataSource() {  
        log.debug("Configruing Write druid DataSource");  
          
        DruidDataSource dataSource = new DruidDataSource();  
        log.info("jdbc.getUsername()="+jdbc.getUsername());
        log.info("jdbc.getUrl()="+jdbc.getUrl());
        log.info("jdbc.getPassword()="+jdbc.getPassword());
        log.info("driver-class-name="+propertyResolver.getProperty("driver-class-name"));
        dataSource.setUrl(jdbc.getUrl()); 
        dataSource.setUsername(jdbc.getUsername());//用户名  
        dataSource.setPassword(jdbc.getPassword());//密码  
        dataSource.setDriverClassName(propertyResolver.getProperty("driver-class-name"));  
        dataSource.setInitialSize(jdbc.getInitialSize());  
        dataSource.setMaxActive(jdbc.getMaxActive());  
        dataSource.setMinIdle(jdbc.getMinIdle());  
        dataSource.setMaxWait(jdbc.getMaxWait());  
        dataSource.setTimeBetweenEvictionRunsMillis(Integer.parseInt(propertyResolver.getProperty("timeBetweenEvictionRunsMillis")));  
        dataSource.setMinEvictableIdleTimeMillis(Integer.parseInt(propertyResolver.getProperty("minEvictableIdleTimeMillis")));  
        dataSource.setValidationQuery(jdbc.getValidationQuery());  
        dataSource.setTestOnBorrow(Boolean.getBoolean(propertyResolver.getProperty("testOnBorrow")));  
        dataSource.setTestWhileIdle(Boolean.getBoolean(propertyResolver.getProperty("testWhileIdle")));  
        dataSource.setTestOnReturn(Boolean.getBoolean(propertyResolver.getProperty("testOnReturn")));  
        dataSource.setPoolPreparedStatements(Boolean.getBoolean(propertyResolver.getProperty("poolPreparedStatements")));  
        dataSource.setMaxPoolPreparedStatementPerConnectionSize(Integer.parseInt(propertyResolver.getProperty("maxOpenPreparedStatements")));  
        //配置监控统计拦截的filters，去掉后监控界面sql无法统计，'wall'用于防火墙  
        try {
			dataSource.setFilters(propertyResolver.getProperty("filters"));
		} catch (SQLException e) {
			e.printStackTrace();
		} 
          
        return dataSource;  
    } 
	
}
```
5. 配置文件值映射到类中方法，一是通过set方法注入，二是通过实现EnvironmentAware进行处理，方式二参照上面数据源配置类，方式一参照 `JDBC2MysqlConfiguration`类。对于常量类的配置，可以通过@Value来赋值，@Value不能直接为静态变量赋值，所以要通过set方法实现，把@Value写到对应的set方法上，set方法不能是静态的

## SQLFilter、XssShellFilter用来防止sql注入和前端的css、js等的注入
> 1. SqlFilter 验证如下：
```
String badStr = "'|and|exec|execute|insert|drop|table |from|grant|group_concat|column_name|frame|iframe|script|" +
                    "information_schema.columns|table_schema|union|where|select|delete|update|" +
                    "chr|mid|master|truncate|declare|like|#|<|>";
```
> 2. XssShellFilter验证如下:
```
private static List<Object[]> getXssPatternList() {
        List<Object[]> ret = new ArrayList<Object[]>();
        ret.add(new Object[]{"<(no)?script[^>]*>.*?</(no)?script>", Pattern.CASE_INSENSITIVE});
        ret.add(new Object[]{"eval\\((.*?)\\)", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL});
        ret.add(new Object[]{"expression\\((.*?)\\)", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL});
        ret.add(new Object[]{"(javascript:|vbscript:|view-source:)+", Pattern.CASE_INSENSITIVE});
        ret.add(new Object[]{"<(\"[^\"]*\"|\'[^\']*\'|[^\'\">])*>", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL});
        ret.add(new Object[]{"(window\\.location|document\\.cookie|document\\.|alert\\(.*?\\)|window\\.open\\()+", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL});
        ret.add(new Object[]{"<+\\s*(oncontrolselect|oncopy|oncut|ondataavailable|ondatasetchanged|ondatasetcomplete|ondblclick|ondeactivate|ondrag|ondragend|ondragenter|ondragleave|ondragover|ondragstart|ondrop|onerror=|onerroupdate|onfilterchange|onfinish|onfocus|onfocusin|onfocusout|onhelp|onkeydown|onkeypress|onkeyup|onlayoutcomplete|onload|onlosecapture|onmousedown|onmouseenter|onmouseleave|onmousemove|onmousout|onmouseover|onmouseup|onmousewheel|onmove|onmoveend|onmovestart|onabort|onactivate|onafterprint|onafterupdate|onbefore|onbeforeactivate|onbeforecopy|onbeforecut|onbeforedeactivate|onbeforeeditocus|onbeforepaste|onbeforeprint|onbeforeunload|onbeforeupdate|onblur|onbounce|oncellchange|onchange|onclick|oncontextmenu|onpaste|onpropertychange|onreadystatechange|onreset|onresize|onresizend|onresizestart|onrowenter|onrowexit|onrowsdelete|onrowsinserted|onscroll|onselect|onselectionchange|onselectstart|onstart|onstop|onsubmit|onunload)+\\s*=+", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL});
        return ret;
    }
```

## Consul配置
> 1. Consul的配置在公共模块的bootstrap.yaml文件中进行了配置，其他项目中不要添加bootstrap.yaml的文件，如果需要使用bootstrap的配置文件，请使用bootstrap.yml或者bootstrap.properties，内容如下：
```
server:
   error:
     path: /500.html
   session-timeout: 30
   session:
     cookie.http-only: true
           #cookie.domain= 
           #cookie.max-age: -1
           #cookie.path:  
           
# DATASOURCE
spring:
    session:
      store-type: none 
    jackson:
      date-format: yyyy-MM-dd HH:mm:ss
      time-zone: GMT+8
    datasource:
        name: postmall
        #driver-class-name: oracle.jdbc.driver.OracleDriver
        #driver-class-name: com.mysql.jdbc.Driver
        driver-class-name: com.mysql.jdbc.Driver
        type: com.alibaba.druid.pool.DruidDataSource
        filters: stat
        timeBetweenEvictionRunsMillis: 60000
        minEvictableIdleTimeMillis: 300000
        testWhileIdle: true
        testOnBorrow: false
        testOnReturn: false
        poolPreparedStatements: true
        maxOpenPreparedStatements: 20
    zipkin:
      base-url: ${zipkin-base-url}
    cloud:
      consul:
      #instanceId默认诶服务名+端口（集群时id会重复）， 已经在Java中做了配置，值为spring.application.name-ip-port格式
      #healthCheckUrl和healthCheckPath都配置情况下以healthCheckUrl为准，项目中如果healthCheckUrl为空则使用本机IP和服务端口进行心跳监听
        host: ${consul-host}:${consul-port}
        #port: 8500
        enabled: true
        discovery:
          enabled: true
          #instanceId: ${spring.application.name}:${spring.application.instance_id:${random.value}}
          serviceName: ${spring.application.name}
          preferIpAddress: true
          port: ${server.port}
          healthCheckPath: ${server.context-path}/health
          healthCheckUrl: http://${server-provider-host}${server.context-path}/health
          #healthCheckInterval: 10s      
     # HTTP ENCODING  
    http:  
        encoding.charset: UTF-8  
        encoding.enable: true  
        encoding.force: true  
    #spring mvc  
    mvc:
        view.prefix: /WEB-INF/view/
        view.suffix: .jsp
        static-path-pattern: /**  
#该配置是让Hystrix的超时时间改为5秒，可以解决hystrix第一次访问失败的问题，因为默认我1s，第一次初始化需要时间比较长
hystrix:
  command:
    default: 
      execution: 
        isolation:
          thread.timeoutInMilliseconds: 5000
          strategy: SEMAPHORE
#禁用feign的hystrix
#feign.hystrix.enabled=false
feign:
   hystrix:
     enabled: true
   httpclient:
     enabled: true
   compression: 
   #请求和响应GZIP压缩支持
     request.enabled: true
     response.enabled: true
  #支持压缩的mime types
     request.mime-types: text/xml,application/xml,application/json
     request.min-request-size: 2048
endpoints:
  shutdown:
    enabled: true
    sensitive: true
  restart:
    enabled: true
  health:
    sensitive: false
      
```
> 2.  ${zipkin-base-url}、${consul-host}:${consul-port} 、${server-provider-host}均在项目中自定义配置文件中进行配置即可，系统会自动获取
> 3. beta和prd均是通过域名访问应用，${server-provider-host}为对应的域名，healthCheckUrl和healthCheckPath都配置情况下以healthCheckUrl为准，配置中会从healthCheckUrl中解析对应的主机域名和端口，如果端口为空则设置为80（只有域名时才会为空），项目中如果healthCheckUrl为空或者配置格式不正确则使用本机IP和服务端口进行心跳监听。这样配置为了解决beta和生产环境下，不能通过ip+端口访问的问题
> 4. 如果需要使用hystrix的看板功能feign.hystrix.enabled设置为TRUE
> 5. instanceId默认诶服务名+端口（集群时id会重复）， 在Java中做了配置，值为spring.application.name-ip-port格式,不建议使用随机数配置，如果使用了随机数，服务每重启一次，服务下就会多出一条记录，如果集群时服务太多，看起来比较费劲
```
public class ConsulConfig {
	private static Logger logger = LoggerFactory.getLogger(ConsulConfig.class);
	@Autowired
	ConsulDiscoveryProperties properties;
	public void initConsulConfig() throws Exception {
		String hostIp = properties.getIpAddress();
		String serverProviderHost = null;
		Integer serverProviderPort = null;
		if(StringUtils.isNotBlank(properties.getHealthCheckUrl())){
			Pattern pattern = Pattern.compile("([a-zA-Z0-9]{0,32}[.])+[a-zA-Z0-9]{0,32}([:][1-9][0-9]{1,6})?",Pattern.CASE_INSENSITIVE);
			Matcher matcher = pattern.matcher(properties.getHealthCheckUrl());
			if(matcher.find()){
				String tmpHost = matcher.group(0);
				String []tmp = tmpHost.split(":");
				if(tmp.length == 2){
					serverProviderHost = tmp[0];
					serverProviderPort = Integer.valueOf(tmp[1]);
				}else{
					serverProviderHost = tmp[0];
					serverProviderPort = 80;
				}
			}
		}
		logger.info("修改consul中instanceId的值，使用服务名+IP+端口,确保同一个服务在注册中心只有一条记录;hostIp="+hostIp);
		//如果是本地测试使用本地IP和HealthCheckPath，非本地环境使用域名和80端口，通过tag=dev来判断
		if(serverProviderHost == null){
			properties.setHealthCheckUrl(null);
		}else{
			properties.setIpAddress(serverProviderHost);
			properties.setHealthCheckPath(null);
			properties.setPort(serverProviderPort);
		}
		logger.info("start service serverPort="+properties.getPort());
		// InstanceId默认为applicationName+端口，使用applicationName+ip + 端口，防止集群时默认名字重复
		if(StringUtils.isBlank(properties.getInstanceId()))
			properties.setInstanceId(properties.getServiceName()+"-"+hostIp+"-"+properties.getPort());
	}
}
```

## 公共帮助类
目前已收集的工具类如下：

| 类名 |  描述 |
| :---------------- | :---------- |
| BeanUtils | 替代了common包中的BeanUtils，为了解决字符串日期转对象时的格式问题|
| DataUtil | 转换HttpServletRequest对象中的指定key，根据需要调用对应方法获取需要类型的数据，方法有parseString,parseLong,parseDouble,parseInt；parseInt(Object str)，boolean isNumber(String str)，汉字转换成拼音String toPinyin(String input)，String ToDBC(String input)|
| HttpClientUtil | sendPost|
| MD5Tools | 获取系统默认分隔符String getOSFileSeparator()，获取加密后的字符串 String getMD5Password(String password) ，获取指定日期的年月日int getYear(final Date date)，int getMonth(final Date date)，int getDay(final Date date)，int getHour(final Date date)，int getMinute(final Date date)，int getSecond(final Date date)|
| ResultDTO<T> | 所有rest接口统一返回对象 |
| LocalDeveloyEnv | 判断是否为dev开发的一个常量，可以在本地服务启动时添加系统变量 `dev=true` ，有些逻辑或验证在开发时不需要使用，可以使用类中的isDev进行判断，目的是：提交代码无需修改，所有项目建议用spring-boot:run 命令进行启动，在命令下方设置dev变量 |


> 1. 通过jackson的配置`spring.jacksondate-format: yyyy-MM-dd HH:mm:ss`，日期转成json的输入输出都是`yyyy-MM-dd HH:mm:ss`格式，所以在通过BeanUtils进行bean的复制时，时间需要进行处理,common中提供了自己的BeanUtil工具类进行了处理，如果用到了对象复制功能请使用改类
> 2. DataUtil,HttpClientUtil,MD5Tools目前每个项目都有这个类，以后请用公共的工具类，如果不能满足请提出了，如确实需要，添加相应功能
> 3. ResultDTO，定义为所有rest接口统一返回改对象，如果无需数据的返回直接定义 success方法，如需数据调用 success(T data)方法，如果失败请调用 fail()方法；还可以直接自己创建对象进行调用，该类中添加了remark属性留作备用
```
public final class ResultDTO<T> implements Serializable{
	
	private String code;
	private String msg;
	private String remark;
	private T data;
	
	
	
	public static ResultDTO<Object> success(){
		ResultDTO<Object> rst = new ResultDTO<Object>();
		rst.setCode("0000");
		return rst;
	}
	public static <T> ResultDTO<T> success(T data){
		ResultDTO<T> rst = new ResultDTO<T>();
		rst.setCode("0000");
		rst.setData(data);
		return rst;
	}
	public static ResultDTO<Object> fail(String msg){
		ResultDTO<Object> rst = new ResultDTO<Object>();
		rst.setCode("0001");
		rst.setMsg(msg);
		return rst;
	}
    ...
```
## CommonApplication
在common中提供了一个 CommonApplication，其他使用common的项目需要继承，CommonApplication的存在做了一下几个事情
> 1. 创建公共常量的bean初始化常量值
> 2. 添加sleuth的日志写入配置
```
@Bean
    public AlwaysSampler defaultSampler(){
        return new AlwaysSampler();
    }
```
> 3. 便于后期对所有服务的公共部分进行扩展，比如添加公共的过滤器
> 4. 减少项目中Application的注解，`@SpringBootApplication` `@EnableDiscoveryClient`
## 日志文件配置
日志文件已经在common中有配置，输入路径为/data/logs/tomcat/wholesale/${项目的上下文名称}/项目的上下文名称.log,项目的上下文名称日志文件会自动从配置文件中获取server.context-path的值，如果不需要设置context-path的请复制配置文件自行设置

## 其他说明
公共模块中的bootstrap.yaml文件中的所有配置都可以在自己项目中进行覆盖，要求必须在application.yml或者properties的配置文件中进行相同属性名的配置，因为spring boot在启动时会先加载bootstrap开头的配置文件，其次才加载application开头的配置文件，后者会覆盖前者相同属性名的配置，另外建议在自己项目中添加bootstrap.yml的配置文件在文件中配置spring.application.name,这样其他组件中如需获取就会读取到真正的name，否则其他加载优先级比较高的组件获取的名字就是默认的bootstrap

# Rest服务实现模块
## Consul初始化
> 1. 在公共模块定义了consul的配置，但是没有加载，所有在这里进行加载使用,一定要实现InitializingBean，这样的bean加载的优先级高，配置才会生效
```
@Component
@Import(ConsulConfig.class)
public class ConsulInitializingBean implements InitializingBean {

	private static Logger logger = LoggerFactory.getLogger(ConsulInitializingBean.class);
//	@Autowired
//	ConsulDiscoveryProperties properties;
	@Autowired
	ConsulConfig consulConfig;
	@Override
	public void afterPropertiesSet() throws Exception {
		logger.info("initConsulConfig ");
		// 一定要在 InitializingBean bean中调用，如果初始化时机比较晚，配置就不起作用了
		consulConfig.initConsulConfig();
	}
}
```
> 2. 如果需要启动时初始化数据可以在InitLinstener类中添加相应代码
```
@Component
public class InitLinstener implements ApplicationListener<ContextRefreshedEvent>{
	private static Log logger = LogFactory.getLog(InitLinstener.class);  
	private static KafkaClientsConfig config = KafkaClientsConfig.DEFAULT_INSTANCE;
	@Override
	public void onApplicationEvent(ContextRefreshedEvent arg0) {
		startRecevier();
		logger.info("consumer init end");
	}
    ...
```
## Mybatis配置
> 1. 在common中添加了mybatis的公共的setting配置，还需要在需要使用数据源的项目中对Mybatis进行配置，在mybatis配置类上引入需要的数据源，如mysql则引入`@Import({ DataBaseMysqlConfiguration.class })`，设置mybatis的mapper的包配置`@MapperScan(basePackages = { "com.ule.wholesale.fxpurchase.server.mapper" })`
```
@Configuration
@Import({ DataBaseMysqlConfiguration.class })
@MapperScan(basePackages = { "com.ule.wholesale.fxpurchase.server.mapper" })
@EnableTransactionManagement
public class MybatisConfiguration implements EnvironmentAware,
		TransactionManagementConfigurer {

	private static Logger logger = LoggerFactory
			.getLogger(MybatisConfiguration.class);

	private RelaxedPropertyResolver propertyResolver;

	@Resource(name = "dataSource")
	private DataSource dataSource;

	@Override
	public void setEnvironment(Environment env) {
		this.propertyResolver = new RelaxedPropertyResolver(env, "mybatis.");
	}

	@Bean
	@ConditionalOnMissingBean
	public SqlSessionFactory sqlSessionFactory() {
		try {
			SqlSessionFactoryBean sessionFactory = new SqlSessionFactoryBean();
			// dataSource = SpringBeanUtil.getBean(DataSource.class);
			sessionFactory.setDataSource(dataSource);
			sessionFactory.setTypeAliasesPackage(propertyResolver.getProperty("typeAliasesPackage"));
			sessionFactory
					.setMapperLocations(new PathMatchingResourcePatternResolver()
							.getResources(propertyResolver
									.getProperty("mapperLocations")));
			sessionFactory
					.setConfigLocation(new DefaultResourceLoader()
							.getResource(propertyResolver
									.getProperty("configLocation")));

			return sessionFactory.getObject();
		} catch (Exception e) {
			logger.warn("Could not confiure mybatis session factory");
			e.printStackTrace();
			return null;
		}
	}

	@Bean
	public SqlSessionTemplate sqlSessionTemplate(
			SqlSessionFactory sqlSessionFactory) {
		return new SqlSessionTemplate(sqlSessionFactory);
	}

	@Bean
	@ConditionalOnMissingBean
	public DataSourceTransactionManager transactionManager() {
		return new DataSourceTransactionManager(dataSource);
	}

	@Override
	public PlatformTransactionManager annotationDrivenTransactionManager() {
		return new DataSourceTransactionManager(dataSource);
	}

	@Bean//引入分页插件
	public PageHelper pageHelper() {
		logger.info("MyBatisConfiguration.pageHelper()");
		PageHelper pageHelper = new PageHelper();
		Properties p = new Properties();
		p.setProperty("dialect", "mysql");
		p.setProperty("offsetAsPageNum", "false");
		p.setProperty("rowBoundsWithCount", "false");
		p.setProperty("pageSizeZero", "true");
		p.setProperty("reasonable", "false");
		p.setProperty("supportMethodsArguments", "false");
		p.setProperty("returnPageInfo", "none");
		pageHelper.setProperties(p);
		return pageHelper;
	}
}
```
> 2. 如需分页操作引入分页插件，代码如上

## Swagger2配置
rest服务建议引入Swagger2的配置，只需要两部操作，如需更详细的配置，需要到对应的类中通过注解进行配置
> 1. 引入jar
```
<dependency>
			<groupId>io.springfox</groupId>
			<artifactId>springfox-swagger2</artifactId>
		</dependency>
		<dependency>
			<groupId>io.springfox</groupId>
			<artifactId>springfox-swagger-ui</artifactId>
		</dependency>
```
> 2. 相关配置
```
@Configuration
@EnableSwagger2
public class Swagger2 {

    @Bean
    public Docket createRestApi() {
        return new Docket(DocumentationType.SWAGGER_2)
                .apiInfo(apiInfo())
                .select()
                .apis(RequestHandlerSelectors.basePackage("server接口的包路径"))
                .paths(PathSelectors.any())
                .build();
    }

    private ApiInfo apiInfo() {
        return new ApiInfoBuilder()
                .title("Spring Boot中使用Swagger2构建RESTful APIs")
                .version("1.0")
                .build();
    }

}
```

## 添加自己的过滤器
> 比如登录和授权的过滤器和添加Servlet
```
@Bean
	public ServletRegistrationBean initUploadImgServlet() {
		ServletRegistrationBean registration = new ServletRegistrationBean(new UploadImgServlet());
		registration.addUrlMappings("/uploadImgServlet");
		return registration;
	}
	
	@Bean
	public FilterRegistrationBean userLoginStatusFilter() {
		FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
			filterRegistrationBean.setFilter(new UserLoginFilter());
			filterRegistrationBean.addInitParameter("exclusions", "*.js,*.gif,*.jpg,*.png,*.css,*.ico,/druid/*");
			filterRegistrationBean.addUrlPatterns(LocalDeveloyEnv.isDev?"":"/*");
		return filterRegistrationBean;
	}
	
	@Bean
	public FilterRegistrationBean authorizationFilter() {
		FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
			filterRegistrationBean.setFilter(new AuthorizationFilter());
			filterRegistrationBean.addInitParameter("exclusions", "*.js,*.gif,*.jpg,*.png,*.css,*.ico,/druid/*");
			filterRegistrationBean.addUrlPatterns(LocalDeveloyEnv.isDev?"":"/*");
		return filterRegistrationBean;
	}
```
## 包命名
包名为com.ule.wholesale.模块名,下面包括 config 、controller、 init 、service 、mapper 、vo ,根据需要添加util（仅在common中没有时）
## 配置修改
根据自己项目修改bootstrap.yml中的信息
![修改项](/images/bootstrap-1.jpg)

# rest接口api
1. rest接口本文是通过FeignClient进行调用，需要配置FeignClient中的value和path属性`@FeignClient(value=ClientConstants.SERVICE_NAME,path=ClientConstants.SERVER_PATH)`
```
	public final static String SERVER_PATH = "fxPurchaseServer";//项目的上下文
	public final static String SERVICE_NAME= "fxpurchase-service-provider";//consul服务注册的服务名，一般和spring.application.name相同
```
2. head验证信息
如果需要通过head进行信息传递，可以把要传递的信息存放于`com.ule.wholesale.fxpurchase.api.constants.ClientConstants.ClientConstants.headMap`这个map中
```
public class ClientsHeadersSettingInterceptor {

	@Autowired
	HttpServletRequest request;
	@Bean
	public RequestInterceptor headerInterceptor() {
		return new RequestInterceptor() {
			@Override
			public void apply(RequestTemplate requestTemplate) {	
                for(String key : ClientConstants.headMap.keySet()){
                    if(ClientConstants.headMap.get(key) != null && StringUtils.isNotBlank(ClientConstants.headMap.get(key).toString()))
                        requestTemplate.header(key, ClientConstants.headMap.get(key).toString());
                }
			}
		};
	}
}
```
3. dto包
存放所有需要暴露给调用者的对象
# 接口调用
## FeignClient配置
> 1. 接口调用分为http调用和FeignClient调用，本文要介绍的是后者.
> 2. feignclient 中集成了hystrix和ribbon，ribon实现了负载客户端的负载均衡，hystrix实现了服务的监控（结合看板），服务断路后重发等功能
> 3. 服务重发默认5次，比如请求超时也会重新请求，这对于新增之类的操作影响比较大，所有项目中禁止重发请求操作，配置如下：
> 4. feign client默认的connectTimeout为10s，readTimeout为60，可以通过下面代码进行修改
```
@Value("${feignConnectTimeout:10000}")
private Integer connectTimeoutMillis;
@Value("${feignReadTimeout:60000}")
private Integer readTimeoutMillis;

// feign client默认的connectTimeout为10s，readTimeout为60.单纯设置timeout，可能没法立马见效，因为默认的retry为5次    
@Bean
Request.Options feignOptions() {
	return new Request.Options(/**connectTimeoutMillis**/connectTimeoutMillis, /** readTimeoutMillis **/readTimeoutMillis);
}
@Bean
Retryer feignRetryer() {
	return Retryer.NEVER_RETRY;
}
```
## FeignClient使用
 接口的使用，在controller直接使用对应的client,和普通service使用方式相同
```
@Autowired
private BankInfoClientService bankInfoClientService;
```
## Consul配置
接口调用者需要配置Consul服务，但是不需要被发现,虽然common中进行了consul的配置，此处配置会覆盖common中的配置，或者说register设置为false，common对应consul配置就无效了
```
srping:
    cloud:
      consul:
        discovery:
          register: false
```
## 其他
 修改server.context-path 和spring.application.name
 在service层编写自己需要的service，比如调用其他http服务的处理等
