#!/bin/bash
# Author: David Deng
# Url: https://covear.top

get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
}

echo -e "\n【 开始同步 】\n"

git init
read -p "请输入本地文件夹路径: " Local
read -p "请输入远程仓库用户名: " User
read -p "请输入远程仓库用户邮箱: " Email
read -p "请输入远程仓库名: " Name
read -p "请输入对本次上传的描述: " MSG
SSH="git@github.com:"${User}"/"${Name}".git"
SSH2="git@gitee.com:"${User}"/"${Name}".git"

cd ${Local}

(
cat <<EOF
# The following file types do not need to be uploaded
*.swp
*.inf.php
inf.php
git_sync
EOF
) >.gitignore


if [ ! -d "./git_sync" ]; then
	echo -e "【 初始化文件夹 】"
	if [ -d "./.git" ]; then
(
cat <<EOF
[core]
        repositoryformatversion = 0
        filemode = true
        bare = false
        logallrefupdates = true

[user]
        email = ${Email}
        name = ${User}

EOF
) >./.git/config

	else
		git init
(
cat <<EOF

[user]
        email = ${Email}
        name = ${User}

EOF
) >>./.git/config
	fi
fi

echo -e "【 添加本地文件 】"
git add ${Local}
echo -e "【 显示文件变化 】"
git status
echo -e "【请按任意键继续】"
char=`get_char`
echo -e "【 更新本地仓库 】"
git commit -m "${MSG}"

echo -e "【 添加Gitee远程仓库 】"
git remote add ${Name} ${SSH2}
echo -e "【 添加Gitee远程链接 】"
git remote set-url ${Name} ${SSH2}
echo -e "【 上传Gitee远程仓库 】"
git push -u ${Name} +master
echo -e "【 删除Gitee远程缓存 】"
git remote rm ${Name}


echo -e "【 添加Github远程仓库 】"
git remote add ${Name} ${SSH}
echo -e "【 添加Github远程链接 】"
git remote set-url ${Name} ${SSH}
echo -e "【 上传Github远程仓库 】"
git push -u ${Name} +master
echo -e "【 删除Github远程缓存 】"
git remote rm ${Name}

echo -e "\n【 同步完成 】\n"

echo \#!/bin/bash >./git_sync
(
cat <<EOF

get_char(){
	SAVEDSTTY=\`stty -g\`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty \$SAVEDSTTY
}

EOF
) >>./git_sync
echo echo -e \"\\n【 开始同步 】\\n\" >>./git_sync
echo cd ${Local} >>./git_sync
echo echo -e \"【 添加本地文件 】\" >>./git_sync
echo git add ${Local} >>./git_sync
echo echo -e \"【 显示文件变化 】\" >>./git_sync
echo git status >>./git_sync
echo read -p \"请输入对本次上传的描述: \" MSG >>./git_sync
echo echo -e \"【描述】: \${MSG}\" >>./git_sync
echo echo -e \"【请按任意键继续】\" >>./git_sync
echo char=\`get_char\` >>./git_sync
echo echo -e \"【 更新本地仓库 】\" >>./git_sync
echo git commit -m \"\${MSG}\" >>./git_sync

echo echo -e \"【 添加Gitee远程仓库 】\" >>./git_sync
echo git remote add ${Name} ${SSH2} >>./git_sync
echo echo -e \"【 添加Gitee远程链接 】\" >>./git_sync
echo git remote set-url ${Name} ${SSH2} >>./git_sync
echo echo -e \"【 上传Gitee远程仓库 】\" >>./git_sync
echo git push -u ${Name} +master >>./git_sync
echo echo -e \"【 删除Gitee远程缓存 】\" >>./git_sync
echo git remote rm ${Name} >>./git_sync

echo echo -e \"【 添加Github远程仓库 】\" >>./git_sync
echo git remote add ${Name} ${SSH} >>./git_sync
echo echo -e \"【 添加Github远程链接 】\" >>./git_sync
echo git remote set-url ${Name} ${SSH} >>./git_sync
echo echo -e \"【 上传Github远程仓库 】\" >>./git_sync
echo git push -u ${Name} +master >>./git_sync
echo echo -e \"【 删除Github远程缓存 】\" >>./git_sync
echo git remote rm ${Name} >>./git_sync

echo echo -e \"\\n【 同步完成 】\\n\" >>./git_sync
echo exit >>./git_sync
chmod +x ./git_sync

echo 【 已于目录${Local}生成“git_sync”文件，您下次进入目录输入“./git_sync”即可 】

exit

