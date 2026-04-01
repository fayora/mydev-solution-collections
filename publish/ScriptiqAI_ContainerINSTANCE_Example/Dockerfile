FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Python, pip, sudo and other essential packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    sudo \
    curl \
    git \
    vim \
    build-essential \
    nano \
    wget \
    byobu \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic link for python (pip3 is already available as pip)
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create a non-root user with sudo privileges
ARG USERNAME=jupyter
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Jupyter Lab and required Python packages
RUN pip install --no-cache-dir \
    jupyterlab \
    notebook \
    ipywidgets \
    tenacity \
    aiohttp \
    asyncio

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Create workspace directory
RUN mkdir -p /home/$USERNAME/workspace

# Copy notebook files from build context to workspace
COPY --chown=$USERNAME:$USERNAME ./Demo-notebooks/*.ipynb /home/$USERNAME/

# Copy custom login page html
COPY --chown=$USERNAME:$USERNAME login.html /usr/local/lib/python3.10/dist-packages/jupyter_server/templates/login.html

# Generate Jupyter config
RUN jupyter lab --generate-config

# Configure Jupyter to use token authentication and allow root
RUN echo "c.ServerApp.allow_root = True" >> /home/$USERNAME/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.ip = '0.0.0.0'" >> /home/$USERNAME/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.open_browser = False" >> /home/$USERNAME/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.port = 8888" >> /home/$USERNAME/.jupyter/jupyter_lab_config.py && \
    echo "c.ServerApp.terminado_settings = {'shell_command': ['/bin/bash']}" >> /home/$USERNAME/.jupyter/jupyter_lab_config.py

# Expose Jupyter port
EXPOSE 8888

# Set environment variable for token
ENV JUPYTER_TOKEN=""

# Start Jupyter Lab with token authentication
# Use exec form to avoid shell interpretation issues with special characters
ENTRYPOINT ["jupyter", "lab"]
CMD ["--ip=0.0.0.0", "--port=8888", "--no-browser", "--ServerApp.allow_root=True"]