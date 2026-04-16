

# Direct inline injection:
docker run -it -v ~/.bashrc:/root/.bashrc debian:trixie bash




# Step by step:

# 1. Pull and start a Debian 13 container
docker run -dit --name test-deb13 debian:trixie bash

# 2. Inject into running container
docker exec -i test-deb13 bash -c 'cat > /root/.bashrc' < ~/.bashrc

# 3. Open a shell to verify
docker exec -it test-deb13 bash




#For Dockerfile
COPY .bashrc /root/.bashrc

