#cloud-config
# This is a Terraform templatefile() template — ${backend_lb_ip} gets substituted
# at `terraform apply` time with the real internal Load Balancer IP.
# See DEPLOYMENT-STEPS.md for the exact templatefile() wiring.
package_update: true
packages:
  - nginx
  - git

write_files:
  - path: /etc/nginx/sites-available/jobtrackr
    content: |
      server {
          listen 80;
          root /var/www/jobtrackr;
          index index.html;

          location /api/ {
              proxy_pass http://${backend_lb_ip}:5000/api/;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
          }

          location /health {
              proxy_pass http://${backend_lb_ip}:5000/health;
          }

          location / {
              try_files $uri $uri/ /index.html;
          }
      }

runcmd:
  - mkdir -p /var/www/jobtrackr
  - git clone https://github.com/AtharvaGhongade/jobtrackr.git /tmp/jobtrackr
  - cp /tmp/jobtrackr/app/frontend/index.html /var/www/jobtrackr/index.html
  - rm -f /etc/nginx/sites-enabled/default
  - ln -sf /etc/nginx/sites-available/jobtrackr /etc/nginx/sites-enabled/jobtrackr
  - systemctl restart nginx
