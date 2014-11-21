#!/bin/bash

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

remote_server=$1
username="root"

echo "Generating local ssh keys if needed"

if [ -f "/root/.ssh/id_rsa" ] ; then
    echo "Local ssh keys already exist"
else
    mkdir -p "/root/.ssh"
    ssh-keygen -t rsa -N "" -f "/root/.ssh/id_rsa"
fi

cat ~/.ssh/id_dsa.pub | ssh ${username}@${remote_server} "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys"
 
exit 0
