if [ "`id -u`" -eq 0 ]; then
	export PS1='\e[36m \w \e[31m#\e[m '
else
	export PS1='\e[36m \w \e[32m#\e[m '
fi
