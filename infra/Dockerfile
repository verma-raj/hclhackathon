# Use official Tomcat image with JDK 17
FROM tomcat:10.1-jdk17

# Remove default ROOT app
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# Create ROOT directory
RUN mkdir -p /usr/local/tomcat/webapps/ROOT

# Copy static files
COPY index.html /usr/local/tomcat/webapps/ROOT/index.html
COPY squad-team.webp /usr/local/tomcat/webapps/ROOT/squad-team.webp

# Expose Tomcat port
EXPOSE 8080

# Start Tomcat
CMD ["catalina.sh", "run"]
